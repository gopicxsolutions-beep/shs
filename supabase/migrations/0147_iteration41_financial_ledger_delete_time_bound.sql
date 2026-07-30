-- Gap-hunt iteration 41: a fresh Financial Ledger audit found a CRITICAL
-- gap in `financial_ledger_delete_staff` (migration 0106) — it restricts
-- deletion to "the current latest row per (shg_id, entry_type)" but never
-- bounds HOW OLD that row is allowed to be. Since deleting the latest row
-- makes the next-most-recent row instantly become the new "latest,"
-- nothing stops a staff account from repeating the delete indefinitely,
-- walking backward through an entire SHG's cashbook/bank/audit history one
-- row at a time — directly contradicting this table's own documented
-- purpose ("this table's entire documented purpose ... is being the SHG's
-- permanent, append-only audit trail", migration 0072).
--
-- Live-verified: a real `crp` account (not the author of any of the 4 real
-- rows in a real SHG's cashbook chain) issued 3 separate sequential
-- deletes and walked the chain from 4 rows down to 1, with every delete
-- succeeding — confirmed via row counts between each step, then rolled
-- back with zero lasting effect.
--
-- Fixed by bounding deletion to the SAME "undo the mistake you just
-- posted" window this policy's own 0106 commit message describes as its
-- intent — a correction is still possible (delete the latest entry within
-- a short grace period, then re-add it correctly), but a historical row
-- more than 15 minutes old can never be deleted by anyone, staff included.
drop policy if exists "financial_ledger_delete_staff" on public.financial_ledger;

create policy "financial_ledger_delete_staff" on public.financial_ledger
  for delete using (
    public.is_staff()
    and created_by <> auth.uid()
    and public.financial_ledger_is_latest(id)
    and created_at > now() - interval '15 minutes'
  );
