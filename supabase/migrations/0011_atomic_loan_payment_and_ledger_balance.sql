-- Fixes 2 real race conditions found this session — the exact same bug
-- class as the marketplace stock issue fixed in
-- 0008_marketplace_stock_decrement_rpc.sql (a "read a numeric field,
-- compute a new value in Dart, write it back" sequence done as two
-- separate round trips, with no atomicity between them), just discovered
-- afterward by specifically auditing for other instances of that same
-- shape.
--
-- 1. LoanRepository.recordPayment(): `newOutstanding` was computed
--    client-side from whatever `loan.outstanding` the loan-detail page
--    happened to load earlier (`lib/pages/loans/loan_detail_page.dart`),
--    not a fresh read at write time. `loans_update_leader_or_staff` RLS
--    allows BOTH the SHG's leader and any staff account to update the
--    same loan, so this is genuinely multi-actor: if a leader and a staff
--    member both record a payment on the same loan around the same time
--    (e.g. reconciling at a group meeting), each computes from the same
--    stale `outstanding`, and whichever write lands second silently
--    overwrites (not adds to) the first payment's effect on the balance —
--    a real, financially-impactful lost update, understating what's
--    actually still owed.
--
-- 2. FinancialRepository.addEntry(): the running "balance" is computed as
--    `previousBalance + credit - debit`, where `previousBalance` is read
--    from the most recent row for the same (shg_id, entry_type) in one
--    round trip, then a new row is inserted with the computed balance in
--    a SEPARATE round trip. `financial_ledger_write_leader_or_staff`
--    again allows both the leader and staff to post entries, so two
--    concurrent postings (e.g. one credit, one debit, at a meeting) can
--    both read the same stale "previous balance" and each compute a
--    balance that only reflects their own entry — the ledger silently
--    loses track of one of the two entries' effect on the running total,
--    permanently, since every later entry chains forward from whichever
--    wrong balance was inserted last.
--
-- Fix: two `security invoker` (NOT `security definer` — unlike the
-- marketplace fix, there's no RLS permission boundary to cross here,
-- `loans_update_leader_or_staff`/`financial_ledger_write_leader_or_staff`
-- already permit the caller directly; this is purely about atomicity) RPCs
-- that do the read-and-write as one atomic statement/transaction each.

-- A single atomic UPDATE ... RETURNING both reads the CURRENT row value
-- and writes the new one in one statement — Postgres holds a row lock for
-- the duration, so a second concurrent call for the same loan_id
-- genuinely waits for the first to commit, then correctly computes from
-- the now-updated value, instead of both computing from the same stale
-- snapshot.
-- Also rejects an overpayment (p_amount > the loan's current outstanding
-- balance) rather than silently clamping it — clamping `outstanding` to 0
-- while still inserting the FULL caller-supplied amount into
-- `loan_payments` (the original version of this function did exactly
-- that, matching a gap that also existed client-side in
-- `loan_detail_page.dart`) would leave the payment history permanently
-- overstating what was actually owed/collected: `outstanding` reads 0/
-- closed, but the sum of `loan_payments.amount` for this loan no longer
-- reconciles with `loan.amount`. The client now blocks this in the UI
-- too, but the check belongs here as well since this function is the
-- actual trust boundary — any direct RPC caller must go through it.
create or replace function public.record_loan_payment(p_loan_id uuid, p_amount numeric)
returns table (new_outstanding numeric, closed boolean)
language plpgsql
as $$
declare
  v_current_outstanding numeric;
  v_new_outstanding numeric;
begin
  if p_amount <= 0 then
    raise exception 'payment amount must be positive';
  end if;

  -- Lock the loan row up front (rather than relying on the UPDATE below to
  -- do it implicitly) so the outstanding-balance check right after is
  -- against a fresh, serialized value — a second concurrent call for the
  -- same loan genuinely waits for the first to commit before evaluating
  -- its own overpayment check, instead of both reading the same stale
  -- pre-payment balance.
  select outstanding into v_current_outstanding
  from public.loans
  where id = p_loan_id
  for update;

  if v_current_outstanding is null then
    raise exception 'loan not found';
  end if;

  if p_amount > v_current_outstanding then
    raise exception 'payment amount (%) exceeds outstanding balance (%)', p_amount, v_current_outstanding;
  end if;

  insert into public.loan_payments (loan_id, amount) values (p_loan_id, p_amount);

  update public.loans
  set outstanding = v_current_outstanding - p_amount,
      status = case when v_current_outstanding - p_amount <= 0 then 'closed' else status end
  where id = p_loan_id
  returning outstanding into v_new_outstanding;

  -- This function is `security invoker` (see the comment above), so the
  -- UPDATE above is still subject to `loans_update_leader_or_staff` — which
  -- only permits the loan's SHG leader or staff, NOT the borrowing member
  -- themselves. `loan_payments_insert_related`, by contrast, DOES permit
  -- the loan's own member to insert a payment against their own loan. That
  -- asymmetry means a plain member calling this RPC directly (e.g. via the
  -- REST API, bypassing the app's own `canRecordPayment` staff/leader-only
  -- UI gate) would have the INSERT above succeed while this UPDATE is
  -- silently filtered down to 0 rows by RLS — UPDATE...RETURNING INTO does
  -- NOT raise an error for 0 matched rows, it just sets v_new_outstanding
  -- to NULL — so the function would return a (null, null) row looking like
  -- a normal (if odd) result instead of failing, leaving a real
  -- loan_payments row recorded with the loan's `outstanding` balance never
  -- actually decremented: a payment that's "recorded" but not reflected in
  -- what's still owed, and no exception for the caller to notice. `FOUND`
  -- is set by the UPDATE immediately above, so this catches exactly that
  -- silent-RLS-filter case (as well as a loan deleted mid-transaction) and
  -- aborts the whole call — rolling back the loan_payments insert too,
  -- rather than leaving the two tables inconsistent.
  if not found then
    raise exception 'not authorized to update this loan, or loan not found';
  end if;

  return query select v_new_outstanding, (v_new_outstanding <= 0);
end;
$$;

grant execute on function public.record_loan_payment(uuid, numeric) to authenticated;

-- A row-level `SELECT ... FOR UPDATE` wouldn't help for the very first
-- entry of a given (shg_id, entry_type) — there's no existing row yet to
-- lock. Uses a transaction-scoped advisory lock keyed on both values
-- instead (released automatically when this function's implicit
-- transaction ends), which serializes ANY concurrent callers for the same
-- key regardless of whether rows already exist.
create or replace function public.add_financial_ledger_entry(
  p_shg_id uuid,
  p_entry_type text,
  p_description text,
  p_debit numeric,
  p_credit numeric,
  p_created_by uuid
)
returns numeric
language plpgsql
as $$
declare
  v_previous_balance numeric;
  v_new_balance numeric;
begin
  perform pg_advisory_xact_lock(hashtextextended(p_shg_id::text || ':' || p_entry_type, 0));

  select balance into v_previous_balance
  from public.financial_ledger
  where shg_id = p_shg_id and entry_type = p_entry_type
  order by entry_date desc, created_at desc
  limit 1;

  v_new_balance := coalesce(v_previous_balance, 0) + p_credit - p_debit;

  insert into public.financial_ledger (shg_id, entry_type, description, debit, credit, balance, created_by)
  values (p_shg_id, p_entry_type, p_description, p_debit, p_credit, v_new_balance, p_created_by);

  return v_new_balance;
end;
$$;

grant execute on function public.add_financial_ledger_entry(uuid, text, text, numeric, numeric, uuid) to authenticated;
