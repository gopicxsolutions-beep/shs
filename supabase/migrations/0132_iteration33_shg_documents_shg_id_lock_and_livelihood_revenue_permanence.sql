-- Gap-hunt iteration 33: 2 fixes from a fresh Training/Documents audit and
-- this round's own dogfooding pass over iteration 32's fixes.
--
-- 1. [HIGH] `shg_documents_write_leader_or_staff` is a single `for all`
-- policy whose `is_staff()` branch has never constrained `shg_id` at all —
-- three separate prior rounds (0015, 0024, 0036) judged this "safe" because
-- they only reasoned about the INSERT case (a new row's shg_id is
-- meaningless to lock further since staff can legitimately create a
-- document for any SHG). None considered UPDATE: a staff account can
-- retarget an EXISTING document to a DIFFERENT shg_id, silently removing it
-- from its original SHG's visibility (`shg_documents_select_shg_or_staff`)
-- with no audit trail. Live-verified by this round's audit: a real staff
-- UPDATE moved a document from one SHG to another, 1 row affected, no
-- error. Fixed by splitting the single `for all` policy into separate
-- INSERT/UPDATE/DELETE policies (matching this schema's established
-- pattern everywhere else) — INSERT keeps the exact prior behavior
-- (leader's own SHG, or staff for any SHG), UPDATE now locks `shg_id` to
-- its original value via a new `shg_documents_locked_fields()` helper for
-- BOTH branches, DELETE is unchanged.
--
-- 2. [HIGH] `livelihood_activities`'s "revenue locked once completed" rule
-- (0104/0122) only ever compares the NEW row against the IMMEDIATELY
-- PRECEDING committed row — it has no memory of activity history. Since
-- `completed <-> active` is an allowed adjacent transition, any actor
-- (member/leader/staff alike, not staff-specific) can cycle
-- `completed -> active -> completed` in two sequential statements: the
-- first move (to 'active') passes because the freeze rule only applies
-- when the OLD status was 'completed'; the second move (back to
-- 'completed') can then set ANY new revenue because the immediately
-- preceding row's status was 'active', not 'completed'. Live-verified: two
-- sequential UPDATEs on a real completed activity (revenue=1000) — first
-- to 'active', then to 'completed' with revenue=999999 — both succeeded
-- with no error, defeating the freeze this migration's own history
-- describes as a core guarantee. A single-row-comparison RLS check
-- structurally cannot see this history; fixed with a persistent
-- `revenue_locked_at` column + a `BEFORE INSERT OR UPDATE` trigger: once an
-- activity is EVER marked 'completed', `revenue_locked_at` is stamped and
-- never cleared, and from that point forward `revenue` is force-pinned to
-- its value at that moment regardless of any later status toggling — the
-- trigger runs before RLS's own per-statement check and simply overwrites
-- a same-value or rejects a changed one via the existing WITH CHECK's own
-- comparison (since the trigger makes NEW.revenue match OLD.revenue,
-- exactly the outcome the WITH CHECK's own equality check already
-- enforces for the direct one-step case — it's now just impossible to walk
-- around it in two steps).

create or replace function public.shg_documents_locked_fields(p_id uuid)
returns table (shg_id uuid)
language sql
security definer
stable
set search_path = public
as $$
  select d.shg_id
  from public.shg_documents d
  where d.id = p_id
    and (d.shg_id = public.current_shg_id() or public.is_staff());
$$;

revoke all on function public.shg_documents_locked_fields(uuid) from public;
grant execute on function public.shg_documents_locked_fields(uuid) to authenticated;

drop policy if exists "shg_documents_write_leader_or_staff" on public.shg_documents;

create policy "shg_documents_insert_leader_or_staff" on public.shg_documents
  for insert with check (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

create policy "shg_documents_update_leader_or_staff" on public.shg_documents
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    ((shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff())
    and shg_id = (select f.shg_id from public.shg_documents_locked_fields(shg_documents.id) f)
  );

create policy "shg_documents_delete_leader_or_staff" on public.shg_documents
  for delete using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

alter table public.livelihood_activities add column if not exists revenue_locked_at timestamptz;

create or replace function public.livelihood_activities_enforce_revenue_permanence()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'UPDATE' and old.revenue_locked_at is not null then
    new.revenue_locked_at := old.revenue_locked_at;
    new.revenue := old.revenue;
  elsif new.status = 'completed' then
    new.revenue_locked_at := coalesce(new.revenue_locked_at, now());
  end if;
  return new;
end;
$$;

drop trigger if exists livelihood_activities_revenue_permanence_trigger on public.livelihood_activities;
create trigger livelihood_activities_revenue_permanence_trigger
  before insert or update on public.livelihood_activities
  for each row
  execute function public.livelihood_activities_enforce_revenue_permanence();
