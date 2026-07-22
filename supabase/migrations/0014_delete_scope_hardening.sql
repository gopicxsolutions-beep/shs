-- Round 13 of this session: rounds 11-12 exhaustively re-checked every RLS
-- `update`/`all` policy for missing/buggy `with check` clauses (7 confirmed
-- bugs fixed across 0009/0012/0013). This migration applies the same
-- exhaustive methodology to a surface that hadn't had a dedicated pass yet:
-- DELETE policies specifically — i.e. even where `with check` is irrelevant
-- (DELETE has no NEW row to check), is the `using` clause actually scoped to
-- the right rows, and should this row be hard-deletable by this actor at
-- all? Every table's SELECT policy was also re-audited for cross-SHG or
-- cross-role read leakage (`profiles`, `payments`, everything holding
-- personal/financial data) and found already correctly scoped — see the
-- session log for the full table-by-table SELECT verdict list; no SELECT
-- fix is needed in this migration.
--
-- Two confirmed DELETE-scope bugs found, both on financial-record tables
-- that should behave as an append-only audit trail once a figure has been
-- recorded — matching the standard this schema's own comments already hold
-- other tables to (`audit_log`: "No update/delete policies are defined, so
-- the log is immutable from the client"; `financial_ledger.created_by` was
-- made NOT NULL in 0006 specifically because "financial_ledger is the audit
-- ledger itself, so a row with no actor attached defeats its purpose").
-- Neither table's leader-facing repository (`SavingsRepository`,
-- `FinancialRepository`) has ever called `.delete()` — grepped the whole
-- `lib/` tree for `.delete()` and the only hit anywhere in the app is
-- `SchemeRepository.deleteScheme()` (admin-only, matches
-- `schemes_write_admin`) — so closing both gaps costs zero real app
-- functionality; they were only ever reachable via a direct REST call.
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1. savings_delete_leader_or_staff — an SHG leader could permanently
--    delete ANY member's savings_entries row in her own SHG, including
--    already-`verified` ones, with no trace left behind at all.
-- ─────────────────────────────────────────────────────────────────────────
-- `for delete using ((shg_id = current_shg_id() and current_role() =
-- 'leader') or is_staff())`. Round 12 already flagged (but deliberately did
-- not fix) that `savings_update_leader_or_staff` lets a leader self-verify
-- her own submitted entry, judging that lower-stakes because it "moves no
-- money OUT of the SHG" and merely mis-marks a status flag that still
-- leaves the row itself, and the underlying entry, visible for the group to
-- catch at the next meeting. DELETE is a materially different and strictly
-- worse capability than that UPDATE: a leader who has already collected a
-- member's cash deposit could record it (or let it be recorded), then
-- simply delete the `savings_entries` row afterward — the deposit vanishes
-- from the member's own history, the SHG's running total silently drops by
-- exactly that amount, and unlike the self-verify case there is no residual
-- row of any status for the member or another leader/staff reviewer to
-- ever notice or dispute. This is exactly the "financial record that
-- should never be hard-deletable except by staff, since deleting it
-- silently corrupts a running balance/ledger with no trace" shape this
-- audit round specifically went looking for. Fix: restrict DELETE to staff
-- only, matching the `payments_delete_staff` precedent 0013 already
-- established for the same reasoning on a different financial table; the
-- leader keeps her existing (legitimate, actually-used) INSERT and UPDATE
-- (verify) rights untouched.
drop policy if exists "savings_delete_leader_or_staff" on public.savings_entries;

create policy "savings_delete_staff" on public.savings_entries
  for delete using (public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- 2. financial_ledger_write_leader_or_staff — a leader could delete (or
--    edit) an already-posted cashbook/ledger/bank/audit row for her own
--    SHG, not just insert new ones.
-- ─────────────────────────────────────────────────────────────────────────
-- `for all using ((shg_id = current_shg_id() and current_role() = 'leader')
-- or is_staff()) with check (same)` — a single FOR ALL policy, so it covers
-- INSERT, UPDATE, and DELETE identically. `FinancialRepository` (`lib/
-- repositories/financial_repository.dart`) only ever calls `.insert()` (via
-- `addEntry()`/`add_financial_ledger_entry`) — there is no update or delete
-- method anywhere in the app, so the UPDATE/DELETE branches of this policy
-- are pure unused REST-only surface, exactly like the `shgs`/
-- `marketplace_orders` gaps 0013 already fixed despite having no live-UI
-- path either. `financial_ledger` is explicitly this schema's audit ledger
-- (0006's own comment: "financial_ledger is the audit ledger itself, so a
-- row with no actor attached defeats its purpose" — the reasoning it used
-- to justify making `created_by` NOT NULL applies just as much to not
-- letting the row disappear or get silently rewritten afterward). Left as
-- FOR ALL, a leader could `PATCH` or `DELETE` a `credit`/`debit`/`balance`
-- row from an earlier meeting to rewrite her own SHG's cashbook history —
-- covering up a shortfall or an unauthorized withdrawal with no trace,
-- since deleting a mid-sequence ledger row also silently invalidates every
-- later row's running `balance` (each one is computed by
-- `add_financial_ledger_entry` as `previous ± this entry` — see 0011 — so a
-- gap in the middle desyncs every balance after it with nothing recording
-- that a row is even missing). Fix: split the single FOR ALL policy into
-- three scoped ones — INSERT keeps the leader's existing, actually-used
-- ability to post new entries at a meeting; UPDATE and DELETE become
-- staff-only, since (like `payments`) no real feature needs a leader to
-- modify or remove a ledger row after the fact, and doing so is precisely
-- what an audit ledger exists to make impossible for the party being
-- audited.
drop policy if exists "financial_ledger_write_leader_or_staff" on public.financial_ledger;

create policy "financial_ledger_insert_leader_or_staff" on public.financial_ledger
  for insert with check (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

create policy "financial_ledger_update_staff" on public.financial_ledger
  for update using (public.is_staff()) with check (public.is_staff());

create policy "financial_ledger_delete_staff" on public.financial_ledger
  for delete using (public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- Full DELETE-policy verdict (all tables with row-level security) and full
-- SELECT-policy verdict are recorded in this round's session-log entry in
-- docs/DEVELOPMENT_PROGRESS.md — not duplicated here to avoid this comment
-- drifting out of sync with the policies actually defined above and in
-- 0002/0004/0006/0013.
-- ─────────────────────────────────────────────────────────────────────────
