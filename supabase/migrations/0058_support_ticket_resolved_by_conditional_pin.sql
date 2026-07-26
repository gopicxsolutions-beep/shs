-- Closes a real, live-confirmed misattribution gap 0053 knowingly left open
-- as a stated trade-off, by fixing the actual conflict rather than
-- accepting it.
--
-- 0052 pinned `resolved_by = auth.uid() or null` so a staff account could
-- only ever attribute a resolution to herself. 0053 dropped that pin
-- entirely because it applied to the row's FINAL state on every UPDATE, not
-- just updates that actually changed `resolved_by` — reopening a ticket
-- (moving it back to `in_progress` without touching `resolved_by` at all,
-- per `SupportRepository.updateStatus()`'s own "only pass resolvedBy on a
-- genuine resolution" contract) left the column's existing value in place,
-- which would no longer equal the REOPENING staff member's own `auth.uid()`
-- if a different person originally resolved it — so the pin rejected an
-- entirely legitimate, common workflow along with the misattribution it was
-- meant to catch. 0053's own comment weighed this explicitly and accepted
-- the trade-off: "the misattribution risk it guarded against is real but
-- narrow... not worth blocking a genuine, common workflow to prevent."
--
-- Live-confirmed this round (round 128) that the dropped protection is a
-- real, currently-exploitable gap, not just a theoretical one: a synthetic
-- `__TEST__` staff account resolved a ticket while setting `resolved_by` to
-- a DIFFERENT synthetic staff account's id — succeeded outright, no error,
-- with the second account never having touched the ticket at all. This
-- directly undermines 0052's own stated purpose ("record who resolved/
-- closed a ticket... audit-trail gap, same completeness bar already applied
-- to Financial Records/Scheme Applications").
--
-- But 0053's own two problems don't actually require dropping the pin
-- entirely — they only require the pin to apply CONDITIONALLY, exactly the
-- shape this schema already uses elsewhere (`livelihood_activities_locked_fields`,
-- `marketplace_order_locked_fields`) for "this field may only change to a
-- specific new value, but may also stay exactly as it was": require
-- `resolved_by`'s NEW value to either (a) be unchanged from its current
-- value — covers reopening, where the payload never touches this column at
-- all and Postgres UPDATE semantics leave it exactly as it was — or (b)
-- equal the calling staff member's own `auth.uid()` — covers a genuine
-- first-time resolution. Both of 0053's real workflows keep working
-- (case a for reopening, case b for resolving); only the misattribution
-- shape (setting it to a THIRD value that's neither the existing one nor
-- the caller's own id) is newly rejected.
create or replace function public.support_tickets_locked_fields(p_id uuid)
returns table (resolved_by uuid)
language sql
stable security definer
set search_path = public
as $$
  select t.resolved_by
  from public.support_tickets t
  where t.id = p_id
    and (t.member_id = auth.uid() or public.is_staff());
$$;

drop policy if exists "support_tickets_update_staff" on public.support_tickets;

create policy "support_tickets_update_staff" on public.support_tickets
  for update using (
    is_staff()
  ) with check (
    is_staff()
    and (
      resolved_by is not distinct from (
        select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f
      )
      or resolved_by = auth.uid()
    )
  );
