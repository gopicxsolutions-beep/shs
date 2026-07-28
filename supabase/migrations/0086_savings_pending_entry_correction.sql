-- Gap-hunt iteration 11 finding: a member's own savings entry was
-- permanent from the instant of submission -- `savings_update_leader_or_
-- staff` (0034) locks every column except `status` on UPDATE, and
-- `savings_delete_staff` (0014) deliberately restricts DELETE to staff
-- only. 0014's own reasoning was specifically about a VERIFIED entry: a
-- leader deleting one silently corrupts a running total with no trace.
-- That risk simply doesn't exist for a still-`pending` entry -- it hasn't
-- contributed to any verified balance yet, so deleting it has zero
-- financial-integrity cost. Without this, a member who fat-fingers an
-- amount (or double-submits) has no way to correct it herself, and even
-- her leader can only silently ignore the bad row forever, not remove it.
--
-- Fix: an additional permissive DELETE policy (Postgres OR's multiple
-- permissive policies for the same command together, so this doesn't
-- touch `savings_delete_staff` at all) letting the OWNING member delete
-- her own still-pending entry, or the SHG's leader reject a pending entry
-- on the group's behalf -- both scoped to `status = 'pending'` only, so a
-- verified entry remains exactly as staff-delete-only as 0014 intended.

create policy "savings_delete_self_or_leader_pending" on public.savings_entries
  for delete using (
    status = 'pending'
    and (
      member_id = auth.uid()
      or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    )
  );
