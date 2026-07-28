-- support_tickets_stamp_resolved_at (0053): resolved_at goes stale on
-- same-staff re-resolution.
--
-- The trigger only bumps `resolved_at` when `resolved_by` actually CHANGES
-- value (`new.resolved_by is distinct from old.resolved_by`). Scenario:
-- staff A resolves a ticket (resolved_by=A, resolved_at=T1) -> the ticket
-- is reopened (resolved_by left untouched, still A per
-- `SupportRepository.updateStatus`'s "only send resolved_by when
-- transitioning TO resolved/closed" behavior) -> staff A resolves it AGAIN
-- later. The payload again sends `resolved_by: A` — unchanged from the
-- stored value — so the trigger's condition is false and `resolved_at`
-- never advances, leaving `support_ticket_detail_page.dart`'s "Resolved by
-- A on <date>" banner showing the ORIGINAL resolution date under a ticket
-- that was actually just re-resolved today.
--
-- Fix: stamp `resolved_at` whenever the ticket is newly transitioning INTO
-- resolved/closed (regardless of whether resolved_by's value happens to be
-- unchanged), not only when resolved_by itself changes.

create or replace function public.support_tickets_stamp_resolved_at()
returns trigger
language plpgsql
as $$
begin
  if new.status in ('resolved', 'closed') and old.status not in ('resolved', 'closed') then
    new.resolved_at := now();
  end if;
  return new;
end;
$$;
