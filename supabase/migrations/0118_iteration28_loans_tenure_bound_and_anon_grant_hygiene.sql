-- Gap-hunt iteration 28: two LOW/defense-in-depth findings from the
-- Savings/Loans full lifecycle re-sweep. Neither is exploitable today —
-- both are hardening closures, not fixes for a live bug.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [LOW] `loans_tenure_months_check` only enforced `> 0` — the app's own
--    `loan_apply_page.dart` only ever offers 6/12/18/24 via fixed chips, but
--    a direct REST insert (this app's own threat model per CLAUDE.md: "a
--    hostile client can call the REST API directly") could set an
--    arbitrarily large `tenure_months` (e.g. 999999). `emi` is set
--    independently by the leader at approval time, not derived from
--    `tenure_months`, so this is a cosmetic/data-integrity gap (a
--    nonsensical tenure value displayed on the loan) rather than an
--    exploitable financial one — but worth bounding to match the UI's own
--    intended range regardless.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.loans drop constraint if exists loans_tenure_months_check;
alter table public.loans add constraint loans_tenure_months_check check (tenure_months > 0 and tenure_months <= 60);

-- ─────────────────────────────────────────────────────────────────────────
-- 2. [LOW, defense-in-depth] `anon` still held full table-level grants
--    (SELECT/INSERT/UPDATE/DELETE/TRUNCATE) on `loans`, `loan_payments`,
--    `savings_entries`, and `financial_ledger` — confirmed live via
--    `information_schema.role_table_grants`. Prior anon-grant-hygiene
--    sweeps (migrations 0096/0097) revoked `anon`'s EXECUTE on every
--    SECURITY DEFINER function touching these tables, but never revoked
--    the base TABLE grants themselves. Currently harmless: every RLS
--    policy on these four tables is built on `auth.uid()`/
--    `current_shg_id()`/`is_staff()`, all of which resolve to NULL/false
--    for an anonymous request, so RLS blocks 100% of anon access
--    regardless of the table grant. Closing anyway for consistency with
--    the rest of this schema's hygiene sweeps and to shrink the audit
--    surface for the next reviewer — RLS remains the real boundary either
--    way (CLAUDE.md's own stated principle), this is belt-and-braces only.
-- ─────────────────────────────────────────────────────────────────────────

revoke all on public.loans from anon;
revoke all on public.loan_payments from anon;
revoke all on public.savings_entries from anon;
revoke all on public.financial_ledger from anon;
