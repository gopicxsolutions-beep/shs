-- Re-derives 0016_data_integrity_check_constraints.sql's coverage against
-- EVERY numeric/date column in 0001_init_schema.sql (plus every column any
-- later migration added), not just the four it happened to add checks for.
--
-- Full inventory checked (numeric columns): savings_entries.amount (0001,
-- `> 0`), loans.amount (0001, `> 0`), loans.outstanding (0006, `>= 0`),
-- loans.emi (0016, `>= 0`), loans.tenure_months (0006, `> 0`),
-- loan_payments.amount (0001, `> 0`), financial_ledger.debit/.credit (0016,
-- `>= 0`), financial_ledger.balance (no check — deliberately: it's a
-- running signed balance computed as `previous + credit - debit` by
-- `add_financial_ledger_entry`/0011, and a negative balance is a legitimate
-- overdrawn/debit state, not a nonsensical one, so no non-negative check
-- belongs here), livelihood_activities.investment/.revenue (0016, `>= 0`),
-- marketplace_products.price (0001, `>= 0`), marketplace_products.stock
-- (0016, `>= 0`), marketplace_orders.amount (0006, `> 0`),
-- marketplace_reviews.rating (0001, `between 1 and 5`), course_progress.
-- progress (0001, `between 0 and 100`), payments.amount (0001, `> 0`),
-- analytics_kpis.value (no check — deliberately: `analytics_kpis_write_
-- staff` is staff-only, and this schema consistently treats crp/clf/admin
-- as fully trusted actors everywhere else too (see 0015's own precedent for
-- every other is_staff()-only branch), plus "metric" is a free-text label
-- so a legitimately-negative metric, e.g. a delta/growth-rate KPI, is
-- plausible — constraining it would risk breaking a real value with no
-- confirmed gap behind it).
--
-- Date/timestamp columns checked for nonsensical cross-column ordering:
-- loans.disbursed_on/.next_due_date/.created_at, savings_entries.entry_date,
-- meetings.meeting_date, scheme_applications.applied_on, course_progress.
-- completed_on, shg_join_requests.requested_at/.decided_at (server-set via
-- `now()` inside approve_shg_join_request(), a security-definer function —
-- no client write path exists for decided_at at all, so no gap). None of
-- these dates feed any computation the app relies on (grepped every
-- `lib/pages` and `lib/repositories` use of each — every one is a plain
-- display/formatting read, never a subtraction or duration comparison), so
-- an out-of-order date is a cosmetic oddity, not a "real, visible problem"
-- (financial miscalculation / negative stock / chart-going-haywire) this
-- migration's own bar requires — left alone, matching 0016's own
-- "stylistic completionism" exclusion.
--
-- ─────────────────────────────────────────────────────────────────────────
-- The one confirmed real gap: loans.outstanding has no upper bound.
-- ─────────────────────────────────────────────────────────────────────────
-- `loans.outstanding` already has `>= 0` (0006) but nothing stops it from
-- being set ABOVE `loans.amount` — and unlike `outstanding >= 0` (which the
-- atomic `record_loan_payment` RPC, 0011, also independently enforces by
-- rejecting overpayment), there is no RPC or RLS check anywhere that caps
-- `outstanding` at `amount`:
--   - `loans_update_leader_or_staff` (re-derived against every column in
--     0023_leader_selfpromotion_and_column_lock_gaps.sql) explicitly leaves
--     `outstanding` freely writable to any value for the SHG's leader or
--     any staff account — deliberately, since real approval/payment flows
--     legitimately rewrite it, same as `status`/`emi`/`disbursed_on`/
--     `next_due_date`.
--   - `LoanRepository.recordPayment()`'s own fallback path (used whenever
--     `record_loan_payment` isn't deployed/found — see that function's own
--     doc comment) does `'outstanding': newOutstanding` as a plain client-
--     computed `.update()`, with no server-side re-validation at all.
--   - `LoanRepository.apply()` sets `outstanding: amount` at creation and
--     `LoanRepository`'s `amount` is never rewritten by any call site after
--     that (grepped: the only `'amount':` write is in `apply()`'s own
--     insert), so `outstanding` should never legitimately exceed the loan's
--     original `amount` at any point in its lifecycle.
-- A value of `outstanding` above `amount` is nonsensical on its own terms
-- (you can't owe more than you borrowed) and is far from cosmetic: `amount
-- - outstanding` ("amount repaid so far") is computed pervasively —
-- `member_dashboard.dart`'s loan-progress bar, `loan_tracking_page.dart`,
-- `loan_detail_page.dart`, `loan_statement_page.dart`'s SHG-wide
-- `totalRepaid`, and `analytics_repository.dart`'s repaid-total — every one
-- of these would go negative and render a nonsensical negative "repaid"
-- figure or a progress bar past 100%, exactly the "financial miscalculation
-- flowing into dashboards/reports" bar this audit is checking against.
--
-- Added as NOT VALID rather than a plain `add constraint`: 0001-0023 are
-- confirmed live/deployed on this project, so unlike 0016 itself (which
-- could truthfully claim "none of 0008+ has ever been deployed, so there is
-- no live data that could violate these"), this project may already hold
-- real loan rows. The orchestrating session has no direct SQL query channel
-- (only `supabase db push` for migration files, and the app's own RLS-scoped
-- REST API, which can't see other users' loans) — so instead of a manual
-- "run this SELECT, then run this VALIDATE" two-step handoff, this migration
-- does the check AND the validate itself, inside one transaction: if any
-- existing row already violates the constraint, the whole migration fails
-- loudly with an exception naming the exact count (visible directly in the
-- `supabase db push` output) rather than silently leaving the constraint
-- half-enforced or requiring a separate manual follow-up step.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.loans
  add constraint loans_outstanding_le_amount_check check (outstanding <= amount) not valid;

do $$
declare
  v_bad_count int;
begin
  select count(*) into v_bad_count from public.loans where outstanding > amount;
  if v_bad_count > 0 then
    raise exception 'loans_outstanding_le_amount_check: % existing loan row(s) already violate outstanding <= amount — constraint added as NOT VALID (still enforced on all new writes) but NOT validated against existing data; needs a manual data-correction decision before running `alter table public.loans validate constraint loans_outstanding_le_amount_check`', v_bad_count;
  end if;
  alter table public.loans validate constraint loans_outstanding_le_amount_check;
end $$;
