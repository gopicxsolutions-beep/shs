-- Two gaps found in a fresh audit of Payments and Announcements.
--
-- 1. payments.amount has no server-side upper bound -- same fat-finger gap
--    already closed for loans (0062), savings_entries (0067), and
--    financial_ledger (0072). payments_insert_self_or_staff (0013) only
--    checks member_id; client _maxAmount = 1000000 (payments_qr_page.dart)
--    is UI-only. NOTE: `status` is deliberately left untouched here --
--    0027/0038 already reasoned through and explicitly accepted that
--    `status` is genuinely self-supplied under today's mock-payment-
--    gateway architecture (no real gateway/webhook exists yet to be the
--    actual trust boundary); this migration doesn't revisit that judgment
--    call, only adds the same amount cap every other money-shaped table
--    already has.
--
-- 2. announcements had no server-side length cap, no rate limit on
--    posting, and its UPDATE policy left title/body/category completely
--    open -- a leader/staff could silently rewrite the content of an
--    already-posted announcement every member already saw, with no
--    updated_at/audit trail to detect it. 0039 already reasoned through
--    the identical risk for DELETE on this same "append-only by design"
--    shared feed and restricted it to staff-only, but the functionally
--    equivalent UPDATE path was left open. Fix: cap title/body length
--    (mirroring 0078's support-ticket fix), add a posting rate limit
--    (same shape), and lock UPDATE so title/body/category/shg_id can never
--    change -- the app itself has no edit UI for an existing announcement
--    at all, so this doesn't take anything away from a real workflow.

alter table public.payments add constraint payments_amount_cap check (amount <= 1000000);

alter table public.announcements add constraint announcements_title_length_check check (char_length(title) <= 100);
alter table public.announcements add constraint announcements_body_length_check check (body is null or char_length(body) <= 1000);

drop policy if exists "announcements_insert_leader_or_staff" on public.announcements;

create policy "announcements_insert_leader_or_staff" on public.announcements
  for insert with check (
    (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
    )
    and created_by = auth.uid()
    and created_at = now()
    and (select count(*) from public.announcements a where a.created_by = auth.uid() and a.created_at > now() - interval '1 hour') < 10
  );

-- The UPDATE policy's locked-fields lookup must be dropped/recreated
-- together since Postgres won't let the function's RETURNS TABLE shape
-- change while a live policy still depends on it.
drop policy if exists "announcements_update_leader_or_staff" on public.announcements;

drop function if exists public.announcements_created_at(uuid);

create or replace function public.announcements_locked_fields(p_id uuid)
returns table (created_at timestamptz, shg_id uuid, title text, body text, category text)
language sql
security definer
stable
set search_path = public
as $$
  select a.created_at, a.shg_id, a.title, a.body, a.category
  from public.announcements a
  where a.id = p_id
    and (a.shg_id is null or a.shg_id = public.current_shg_id() or public.is_staff());
$$;

revoke all on function public.announcements_locked_fields(uuid) from public;
grant execute on function public.announcements_locked_fields(uuid) to authenticated;

create policy "announcements_update_leader_or_staff" on public.announcements
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
    )
    and created_by = auth.uid()
    and created_at = (select f.created_at from public.announcements_locked_fields(announcements.id) f)
    and shg_id is not distinct from (select f.shg_id from public.announcements_locked_fields(announcements.id) f)
    and title = (select f.title from public.announcements_locked_fields(announcements.id) f)
    and body is not distinct from (select f.body from public.announcements_locked_fields(announcements.id) f)
    and category is not distinct from (select f.category from public.announcements_locked_fields(announcements.id) f)
  );
