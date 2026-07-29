-- Gap-hunt iteration 23 (round 196): 4 parallel audits (dogfood round 195,
-- Savings full sweep, Loans full sweep, Admin Monitoring/Management) — this
-- migration closes 2 CRITICAL data-integrity gaps plus 1 long-standing
-- MEDIUM forgery gap in Loans.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [CRITICAL] `savings_entries_locked_fields()`'s return list never
--    included `shg_id` — `savings_update_leader_or_staff`'s staff branch
--    locks every OTHER column via this helper but had no constraint on
--    `shg_id` at all (the leader branch is incidentally safe only because
--    its own `WITH CHECK` separately re-asserts `shg_id = current_shg_id()`
--    — a leader can only ever operate inside her own fixed SHG anyway).
--    Live-verified: staff could silently move another member's verified
--    savings deposit into an unrelated SHG via direct REST PATCH — the
--    origin SHG's total silently shrinks, the target SHG's total inflates
--    with a phantom deposit, with no trace. Same class of forgery this
--    session already closed for `financial_ledger`/`marketplace_orders`/
--    `marketplace_reviews` in the immediately preceding rounds, just not
--    yet reached on this table.
-- ─────────────────────────────────────────────────────────────────────────

-- Must drop the dependent policy before the function (its RETURNS TABLE
-- column list is changing, which CREATE OR REPLACE can't do in place).
drop policy if exists "savings_update_leader_or_staff" on public.savings_entries;
drop function if exists public.savings_entries_locked_fields(uuid);

create function public.savings_entries_locked_fields(p_id uuid)
returns table (amount numeric, member_id uuid, mode text, frequency text, entry_date date, created_at timestamptz, shg_id uuid)
language sql
stable security definer
set search_path = public
as $$
  select s.amount, s.member_id, s.mode, s.frequency, s.entry_date, s.created_at, s.shg_id
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
    and (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader')
      or public.is_staff()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. [CRITICAL] `loan_payments_loan_id_fkey` was still `ON DELETE CASCADE`
--    — migration 0063 correctly switched `loans.shg_id`/`loans.member_id`
--    to RESTRICT to prevent an SHG/member deletion from silently erasing
--    loan history, but reasoned `loan_payments.loan_id` could stay CASCADE
--    because "no RLS policy currently even permits" directly deleting a
--    loan row. That premise was already false when 0063 was written —
--    `loans_delete_staff` (self-excluded, staff-only) has existed since
--    migration 0002. Live-verified this round: a staff account deleting
--    another member's `active` loan with real EMI payment history cascaded
--    away every one of that loan's `loan_payments` rows, with zero
--    forensic trace (no DELETE trigger exists on `loans` at all). This
--    also defeated `loan_payments`' own apparent append-only design (no
--    UPDATE/DELETE policy of its own) — it was only "immutable" until
--    someone deleted its parent row. RESTRICT here mirrors 0063's own
--    treatment of the other two FKs on the same table.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.loan_payments drop constraint loan_payments_loan_id_fkey;
alter table public.loan_payments add constraint loan_payments_loan_id_fkey
  foreign key (loan_id) references public.loans(id) on delete restrict;

-- ─────────────────────────────────────────────────────────────────────────
-- 3. [MEDIUM, long-standing, first disclosed in migration 0027] `loan_
--    payments_insert_related`'s member self-branch (`l.member_id =
--    auth.uid()`) let a member directly INSERT a fabricated payment row
--    against her own loan, bypassing `record_loan_payment()` (the app's
--    only real payment-recording path) entirely — no overpayment check,
--    no outstanding-balance update, a forged row indistinguishable from a
--    real leader-recorded payment in the UI's own Payment History list.
--    `loan_detail_page.dart`'s own `canRecordPayment` gate already
--    documents that real SHG practice has the leader/treasurer record EMI
--    payments collected at meetings, "not the member themselves" — no
--    legitimate app feature ever exercises this branch (grep of `lib/`
--    confirms every `loan_payments` write goes through the leader/staff
--    path via `record_loan_payment`). Retiring the unused, exploitable-only
--    branch rather than patching it, matching this session's established
--    precedent for `marketplace_orders_insert_staff`.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "loan_payments_insert_related" on public.loan_payments;

create policy "loan_payments_insert_related" on public.loan_payments
  for insert with check (
    (exists (select 1 from public.loans l where l.id = loan_payments.loan_id and l.shg_id = public.current_shg_id() and public.current_role() = 'leader'))
    or public.is_staff()
  );
