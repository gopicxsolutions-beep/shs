-- Gap-hunt round 192 (iteration 19): dogfooding round 190's own work found
-- two more CRITICAL gaps in the exact "is_staff() branch left wide open"
-- pattern this session has now fixed for loans/marketplace_orders/
-- marketplace_products/savings-insert — this time on UPDATE and DELETE.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [CRITICAL, self-caused in round 190/migration 0101] `savings_update_
--    leader_or_staff`'s staff branch got a `member_id <> auth.uid()`
--    self-exclusion in 0101, but never the `savings_entries_locked_fields()`
--    column lock the leader branch has always had. Any crp/clf/admin could
--    `PATCH` any OTHER member's savings_entries row and rewrite `amount`,
--    `mode`, `frequency`, `entry_date`, `created_at`, even `member_id` —
--    not just flip `status` as intended. Fixed by extending the same
--    column lock already applied to the leader branch to the staff branch
--    too — the fully-correct version of what 0101's own commit message
--    claimed to have done.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "savings_update_leader_or_staff" on public.savings_entries;

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
    and (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader')
      or public.is_staff()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. [CRITICAL, pre-existing, found while diffing for the same pattern]
--    `payments_update_staff`'s `with_check` was bare `is_staff()` — no
--    self-exclusion, no column lock at all. Any staff account could
--    rewrite `amount`/`member_id`/`mode`/`reference`/`status` on any
--    digital-payment row. No call site in lib/ currently issues an
--    `.update()` on `payments` (confirmed by this round's audit), so
--    every column is locked here rather than leaving any one open for a
--    not-yet-built feature to widen deliberately later.
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.payments_locked_fields(p_id uuid)
returns table (member_id uuid, amount numeric, mode text, reference text, status text, created_at timestamptz)
language sql
stable security definer
set search_path = public
as $$
  select p.member_id, p.amount, p.mode, p.reference, p.status, p.created_at
  from public.payments p
  where p.id = p_id
    and (p.member_id = auth.uid() or public.is_staff());
$$;

revoke all on function public.payments_locked_fields(uuid) from public, anon;
grant execute on function public.payments_locked_fields(uuid) to authenticated;

drop policy if exists "payments_update_staff" on public.payments;

create policy "payments_update_staff" on public.payments
  for update using (public.is_staff() and member_id <> auth.uid())
  with check (
    public.is_staff()
    and member_id <> auth.uid()
    and member_id = (select f.member_id from public.payments_locked_fields(payments.id) f)
    and amount = (select f.amount from public.payments_locked_fields(payments.id) f)
    and mode = (select f.mode from public.payments_locked_fields(payments.id) f)
    and reference = (select f.reference from public.payments_locked_fields(payments.id) f)
    and status = (select f.status from public.payments_locked_fields(payments.id) f)
    and created_at = (select f.created_at from public.payments_locked_fields(payments.id) f)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. [HIGH] Staff-only DELETE policies across 5 financial/attendance
--    tables never excluded the caller's own historical rows. A member
--    later promoted to crp/clf/admin (round 189 already documented that
--    `updateUserRole()` never clears the promoted account's prior
--    `shg_id`/history) could permanently erase her own verified savings/
--    loan/ledger/payment/attendance record via direct REST — defeating
--    the audit-trail intent the round-190 CASCADE→RESTRICT sweep was
--    built to protect. Fixed by adding the same self-exclusion shape
--    already used on every UPDATE staff branch in this schema.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "savings_delete_staff" on public.savings_entries;
create policy "savings_delete_staff" on public.savings_entries
  for delete using (public.is_staff() and member_id <> auth.uid());

drop policy if exists "loans_delete_staff" on public.loans;
create policy "loans_delete_staff" on public.loans
  for delete using (public.is_staff() and public.loans_member_id(id) <> auth.uid());

drop policy if exists "financial_ledger_delete_staff" on public.financial_ledger;
create policy "financial_ledger_delete_staff" on public.financial_ledger
  for delete using (public.is_staff() and created_by <> auth.uid());

drop policy if exists "payments_delete_staff" on public.payments;
create policy "payments_delete_staff" on public.payments
  for delete using (public.is_staff() and member_id <> auth.uid());

drop policy if exists "meeting_attendance_delete_staff" on public.meeting_attendance;
create policy "meeting_attendance_delete_staff" on public.meeting_attendance
  for delete using (public.is_staff() and member_id <> auth.uid());
