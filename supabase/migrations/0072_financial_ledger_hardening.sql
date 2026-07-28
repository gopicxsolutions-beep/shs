-- financial_ledger: close the two gaps found during a fresh gap-hunting
-- audit — no amount cap, and still ON DELETE CASCADE from shgs.
--
-- 1. No upper-bound check on debit/credit. `0016_data_integrity_check_
--    constraints.sql` only ever added `debit >= 0`/`credit >= 0` — no
--    matching cap was ever added here, unlike `loans_amount_cap` (0062) and
--    `savings_entries_amount_cap` (0067). `FinancialEntryDialog` only
--    rejects `amount <= 0` client-side, with a 9-digit max length (up to
--    999,999,999) and no server-side backstop at all. A fat-fingered extra
--    digit becomes the new stored `balance` baseline every later entry of
--    that `(shg_id, entry_type)` chains forward from, permanently, via
--    `add_financial_ledger_entry` (0011) — same fat-finger shape the loans/
--    savings caps already close. Same ₹10,00,000 cap for consistency.
--
-- 2. `financial_ledger.shg_id` was still `on delete cascade`
--    (0001_init_schema.sql) — never touched by `0063_loans_delete_cascade_
--    restrict.sql`, which fixed the identical blast-radius shape for loans
--    but didn't extend it here. This is the one table whose entire
--    documented purpose (docs/SRS.md, and 0014/0026's own comments) is
--    being the SHG's permanent, append-only audit trail — an admin
--    deleting a duplicate/defunct SHG (permitted by `shgs_delete_admin`,
--    0002) silently destroys its entire cashbook/ledger/bank/audit history
--    in the same transaction, with no archival step at all. Same RESTRICT
--    fix as 0063, for the same reason: force an explicit decision before a
--    SHG with real financial history can ever be removed, instead of
--    silent data loss.

alter table public.financial_ledger add constraint financial_ledger_amount_cap check (debit <= 1000000 and credit <= 1000000);

alter table public.financial_ledger drop constraint financial_ledger_shg_id_fkey;
alter table public.financial_ledger add constraint financial_ledger_shg_id_fkey foreign key (shg_id) references public.shgs (id) on delete restrict;
