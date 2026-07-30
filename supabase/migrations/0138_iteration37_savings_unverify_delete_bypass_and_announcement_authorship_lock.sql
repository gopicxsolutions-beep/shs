-- Gap-hunt iteration 37: a fresh Savings/Loans audit found a CRITICAL,
-- confirmed way to permanently erase an already-verified savings deposit —
-- the exact class of destructive action `savings_delete_staff` was written
-- to restrict to staff only, fully defeated by chaining two independently
-- reasonable-looking migrations that never re-examined each other:
--
-- `savings_update_leader_or_staff` (0108) locks amount/member_id/mode/
-- frequency/entry_date/created_at/shg_id on UPDATE but has never locked
-- `status` — 0034's own reasoning was that un-verifying in isolation is
-- harmless since every total-savings figure is computed live. Separately,
-- `savings_delete_self_or_leader_pending` (0086) lets a leader DELETE any
-- row with `status = 'pending'` in her own SHG, reasoning the destructive-
-- deletion risk "doesn't exist for a still-pending entry."
--
-- Chained: a leader can (1) UPDATE a fellow member's `verified` entry back
-- to `status = 'pending'` (permitted — status isn't locked), then (2)
-- DELETE it via the now-satisfied pending-DELETE policy — silently erasing
-- a real, previously-confirmed deposit with zero trace (no audit trigger
-- exists on this table). Live-verified end-to-end in a rolled-back
-- transaction against a real `verified` entry: both the UPDATE-to-pending
-- and the subsequent DELETE succeeded (row count 1 each); re-queried after
-- rollback to confirm the real row was untouched.
--
-- Fixed by adding `status` to the locked-fields helper and forbidding the
-- one transition that manufactures DELETE-eligibility: a leader/staff
-- UPDATE can never move a row FROM 'verified' back TO 'pending'. The
-- legitimate `verifyEntry()` flow (pending -> verified) is untouched.
drop policy if exists "savings_update_leader_or_staff" on public.savings_entries;
drop function if exists public.savings_entries_locked_fields(uuid);

create function public.savings_entries_locked_fields(p_id uuid)
returns table (amount numeric, member_id uuid, mode text, frequency text, entry_date date, created_at timestamptz, shg_id uuid, status text)
language sql
stable security definer
set search_path = public
as $$
  select s.amount, s.member_id, s.mode, s.frequency, s.entry_date, s.created_at, s.shg_id, s.status
  from public.savings_entries s
  where s.id = p_id
    and (s.member_id = auth.uid() or s.shg_id = public.current_shg_id() or public.is_staff());
$$;

revoke all on function public.savings_entries_locked_fields(uuid) from public, anon;
grant execute on function public.savings_entries_locked_fields(uuid) to authenticated;

create policy "savings_update_leader_or_staff" on public.savings_entries
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader' and member_id <> auth.uid())
    or (public.is_staff() and member_id <> auth.uid())
  ) with check (
    member_id <> auth.uid()
    and amount = (select f.amount from public.savings_entries_locked_fields(savings_entries.id) f)
    and member_id = (select f.member_id from public.savings_entries_locked_fields(savings_entries.id) f)
    and mode = (select f.mode from public.savings_entries_locked_fields(savings_entries.id) f)
    and frequency = (select f.frequency from public.savings_entries_locked_fields(savings_entries.id) f)
    and entry_date = (select f.entry_date from public.savings_entries_locked_fields(savings_entries.id) f)
    and created_at = (select f.created_at from public.savings_entries_locked_fields(savings_entries.id) f)
    and shg_id = (select f.shg_id from public.savings_entries_locked_fields(savings_entries.id) f)
    and (status <> 'pending' or (select f.status from public.savings_entries_locked_fields(savings_entries.id) f) is distinct from 'verified')
    and (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader')
      or public.is_staff()
    )
  );

-- Also fixes a HIGH gap a fresh Notifications/Announcements audit found:
-- `announcements_update_leader_or_staff` (0081) locks title/body/category/
-- shg_id/created_at but left `created_by` as a bare `= auth.uid()`
-- requirement instead of locking it to its original value like every
-- sibling column — since the policy has no legitimate-edit UI behind it at
-- all (0081's own comment: "the app itself has no edit UI"), the ONLY thing
-- this policy could ever actually change was `created_by`, letting any
-- leader/staff silently reassign authorship of someone else's announcement
-- onto themselves. Live-verified: a different leader in the same SHG
-- UPDATEd `created_by` onto her own id with zero content change and no
-- `updated_at` column to detect it. Chained with `announcements_delete_staff`
-- (`is_staff() and created_by <> auth.uid()`, written specifically to stop
-- a staff member deleting their OWN post to cover tracks), this let one
-- staff account launder authorship of another staff account's post onto a
-- third party, after which the ORIGINAL poster now satisfies
-- `created_by <> auth.uid()` and can delete it outright — defeating the
-- self-deletion guard entirely. Fixed by locking `created_by` to its
-- original value, same as every other column on this policy.
drop policy if exists "announcements_update_leader_or_staff" on public.announcements;
drop function if exists public.announcements_locked_fields(uuid);

create function public.announcements_locked_fields(p_id uuid)
returns table (title text, body text, category text, shg_id uuid, created_at timestamptz, created_by uuid)
language sql
stable security definer
set search_path = public
as $$
  select a.title, a.body, a.category, a.shg_id, a.created_at, a.created_by
  from public.announcements a
  where a.id = p_id
    and (a.shg_id = public.current_shg_id() or a.shg_id is null or public.is_staff());
$$;

revoke all on function public.announcements_locked_fields(uuid) from public, anon;
grant execute on function public.announcements_locked_fields(uuid) to authenticated;

create policy "announcements_update_leader_or_staff" on public.announcements
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  ) with check (
    title = (select f.title from public.announcements_locked_fields(announcements.id) f)
    and body is not distinct from (select f.body from public.announcements_locked_fields(announcements.id) f)
    and category = (select f.category from public.announcements_locked_fields(announcements.id) f)
    and shg_id is not distinct from (select f.shg_id from public.announcements_locked_fields(announcements.id) f)
    and created_at = (select f.created_at from public.announcements_locked_fields(announcements.id) f)
    and created_by is not distinct from (select f.created_by from public.announcements_locked_fields(announcements.id) f)
    and (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader')
      or public.is_staff()
    )
  );
