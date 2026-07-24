-- Table-level data-INTEGRITY audit (as opposed to rounds 11-13's RLS
-- who-can-read/write audit): even for a fully RLS-authorized write, does
-- the schema itself reject nonsensical values? Read every `create table`
-- in 0001_init_schema.sql plus everything 0006_production_hardening.sql
-- already added (it covered loans.outstanding/tenure_months,
-- marketplace_orders.amount, financial_ledger.created_by not null,
-- payments.reference uniqueness, report_snapshots uniqueness) before
-- writing this file, to avoid duplicating those.
--
-- Cross-checked every enum-like `status`/`mode`/`category`/`format`/
-- `role`/`advisor_type`/`report_type` column and every unique-by-app-logic
-- pair (scheme_applications (scheme_id, member_id), meeting_attendance
-- (meeting_id, member_id), course_progress (course_id, member_id),
-- shg_join_requests one-pending-per-member) against lib/repositories and
-- lib/models — all of those already have a `check (... in (...))` or a
-- `unique`/partial-unique-index in the existing migrations. The 4 gaps
-- below are the only confirmed-real ones: money/quantity columns that
-- default to 0 but were never given a "can't go negative" CHECK, so a
-- direct REST write (or a future RPC bug) bypassing the Dart-side/RPC-side
-- validation can currently store a negative value the DB itself will
-- happily keep forever.
--
-- Same deployment status as every migration since 0008: written and
-- ready, NOT yet applied to the live project (no deploy credential this
-- session either) — see the "UNDEPLOYED SECURITY FIX" section at the top
-- of this file's docs/DEVELOPMENT_PROGRESS.md for the full undeployed
-- backlog. Safe to apply directly with no backfill step: none of 0008+
-- has ever been deployed, so there is no live data that could violate
-- these.
--
-- ─────────────────────────────────────────────────────────────────────────
-- financial_ledger.debit / .credit — the audit ledger's own running
-- `balance` is computed as `previous + credit - debit` (see
-- add_financial_ledger_entry, 0011). Neither column, nor that RPC, nor any
-- Dart caller (FinancialRepository.addEntry) rejects a negative debit/
-- credit today — a negative "credit" is functionally a hidden debit (and
-- vice versa) that silently corrupts every later row's chained balance
-- with no trace, in the schema this project's own audit trail depends on.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.financial_ledger add constraint financial_ledger_debit_check check (debit >= 0);
alter table public.financial_ledger add constraint financial_ledger_credit_check check (credit >= 0);

-- ─────────────────────────────────────────────────────────────────────────
-- marketplace_products.stock — decrement_product_stock (0008) only ever
-- guards its own `stock - 1 where stock > 0` decrement; a direct REST
-- PATCH setting `stock` to a negative number outright bypasses that RPC
-- entirely and is never re-checked anywhere else (MarketplaceRepository
-- never validates it client-side either). A negative stock both displays
-- nonsensically to buyers and would let that same negative value pass the
-- RPC's own `stock > 0` guard as increasingly-wrong math once any positive
-- restock brought it back above zero.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.marketplace_products add constraint marketplace_products_stock_check check (stock >= 0);

-- ─────────────────────────────────────────────────────────────────────────
-- loans.emi — every other loan money column (amount, outstanding) already
-- has a check (0001 / 0006), but emi was missed by both. A negative
-- monthly-installment figure is nonsensical and would flow straight into
-- the Loans UI's due-amount displays with no server-side guard today.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.loans add constraint loans_emi_check check (emi >= 0);

-- ─────────────────────────────────────────────────────────────────────────
-- livelihood_activities.investment / .revenue — both default to 0 but were
-- never given a non-negative CHECK, and LivelihoodRepository writes
-- whatever numeric value the Add Activity / Update Progress forms supply
-- with no non-negative validation of its own. A negative investment or
-- revenue is nonsensical on its own terms (LivelihoodActivity.profit =
-- revenue - investment is legitimately allowed to be negative — that's a
-- real loss — but the two inputs to it are not).
-- ─────────────────────────────────────────────────────────────────────────

alter table public.livelihood_activities add constraint livelihood_activities_investment_check check (investment >= 0);
alter table public.livelihood_activities add constraint livelihood_activities_revenue_check check (revenue >= 0);
