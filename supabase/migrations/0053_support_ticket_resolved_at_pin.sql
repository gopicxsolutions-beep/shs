-- ─────────────────────────────────────────────────────────────────────────
-- support_tickets: stamp resolved_at server-side, and relax the
-- resolved_by pin so reopening someone else's resolved ticket still works
--
-- Two problems found in 0052 before either shipped to a real workflow:
--
-- 1. `resolved_at` was left to the client to supply. A `with check` pin
--    only works for a value the server can independently recompute inside
--    the same statement (e.g. `applied_on = current_date`, `created_at =
--    now()` on INSERT — both backed by a column DEFAULT evaluated in the
--    same transaction). An UPDATE has no such default mechanism, so
--    `resolved_at = now()` in a `with check` would compare the client's own
--    submitted timestamp against the server's `now()` and (almost) never
--    match, rejecting every real resolution. A `before update` trigger is
--    the correct mechanism instead: it overwrites whatever the client sent
--    with the server's own clock, the instant `resolved_by` is newly set —
--    mirrors this schema's existing `set_updated_at()` trigger pattern
--    (`0006_production_hardening.sql`), just stamping a different column
--    under a different condition.
--
-- 2. `resolved_by = auth.uid()` in 0052's `with check` applies to the
--    row's FINAL state on every update, not just updates that actually
--    change it. `support_ticket_detail_page.dart` lets staff move a ticket
--    to any of the 4 statuses at any time (including reopening an already-
--    resolved one back to `in_progress`), and `SupportRepository.
--    updateStatus()` only sends `resolved_by` when transitioning TO
--    resolved/closed — reopening leaves the existing `resolved_by`
--    untouched in the payload, so the row's new value is whatever it
--    already was. If a *different* staff member than whoever originally
--    resolved it reopens the ticket, that unchanged old value would no
--    longer equal the reopening caller's own `auth.uid()`, and the pin
--    would reject an otherwise completely legitimate status change. Fixed
--    by dropping that pin — the misattribution risk it guarded against
--    (a staff account raw-API-setting `resolved_by` to a colleague's id)
--    is real but narrow for an internal ticketing tool, and not worth
--    blocking a genuine, common workflow (reopening someone else's ticket)
--    to prevent.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "support_tickets_update_staff" on public.support_tickets;

create policy "support_tickets_update_staff" on public.support_tickets
  for update using (
    is_staff()
  ) with check (
    is_staff()
  );

create or replace function public.support_tickets_stamp_resolved_at()
returns trigger
language plpgsql
as $$
begin
  if new.resolved_by is not null and new.resolved_by is distinct from old.resolved_by then
    new.resolved_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists support_tickets_stamp_resolved_at_trigger on public.support_tickets;
create trigger support_tickets_stamp_resolved_at_trigger
  before update on public.support_tickets
  for each row
  execute function public.support_tickets_stamp_resolved_at();
