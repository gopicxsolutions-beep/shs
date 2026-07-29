-- Gap-hunt iteration 32 (Payments/Financial Ledger audit): closes a
-- financial_ledger-specific instance of the same MVCC per-row-WITH-CHECK
-- bypass migration 0123 closed for payments/support_tickets/announcements/
-- support_messages.
--
-- `financial_ledger_insert_leader_or_staff`'s `balance = coalesce(
-- financial_ledger_previous_balance(shg_id, entry_type), 0) + credit -
-- debit` check is evaluated per row against a pre-statement snapshot — rows
-- in the SAME multi-row INSERT never see each other. Live-verified: a
-- single batched `INSERT ... VALUES (row A), (row B)` for the same
-- (shg_id, entry_type) inserted both rows with an IDENTICAL `balance`, each
-- computed off the same stale prior balance rather than chaining A -> B,
-- corrupting the exact running-total invariant this table exists to
-- guarantee (0011/0072's own comments).
--
-- Unlike the rate-limit case, a simple "recompute against the full table"
-- statement-level trigger can't safely re-validate the chain here: this
-- policy also locks `entry_date = current_date` and `created_at = now()`,
-- both identical for every row in one statement, so same-batch rows for the
-- same (shg_id, entry_type) have no ordering column to chain against even
-- in principle. The real app (`FinancialRepository.addEntry()` / the
-- `add_financial_ledger_entry` RPC and its documented client-side fallback)
-- only ever inserts ONE row per statement anyway — so the correct, minimal
-- fix is to reject any batch containing more than one new row for the same
-- (shg_id, entry_type), closing the forgery vector without touching the
-- single-row path every legitimate caller already uses.

create or replace function public.financial_ledger_enforce_batch_integrity()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1 from new_rows
    group by shg_id, entry_type
    having count(*) > 1
  ) then
    raise exception 'financial_ledger: only one entry per (shg_id, entry_type) may be inserted per statement';
  end if;
  return null;
end;
$$;

drop trigger if exists financial_ledger_batch_integrity_trigger on public.financial_ledger;
create trigger financial_ledger_batch_integrity_trigger
  after insert on public.financial_ledger
  referencing new table as new_rows
  for each statement
  execute function public.financial_ledger_enforce_batch_integrity();
