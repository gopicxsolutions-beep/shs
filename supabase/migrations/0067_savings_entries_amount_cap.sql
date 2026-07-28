-- savings_entries: enforce the same ₹10,00,000 fat-finger cap server-side
-- that migration 0062 already added for loans.
--
-- Found during a broad gap-hunting audit. `SavingsEntryPage` hardcodes
-- `_maxAmount = 1000000` and validates it client-side only —
-- `savings_entries` only ever had `check (amount > 0)` (0001_init_schema.sql),
-- no upper bound, across all 15 migrations that have touched this table.
-- Identical exploit shape to the loans gap 0062 closed: a member/leader
-- can `POST /rest/v1/savings_entries` with an arbitrary large `amount`
-- (still correctly gated to her own SHG by the existing INSERT policy),
-- landing as a normal-looking `pending` entry with no signal it's out of
-- bounds, corrupting the SHG's verified total the moment it's confirmed.

alter table public.savings_entries add constraint savings_entries_amount_cap check (amount <= 1000000);
