-- ─────────────────────────────────────────────────────────────────────────
-- support_tickets: record who resolved/closed a ticket and when
--
-- Unlike `shg_join_requests` (`decided_by` since `0004`) or
-- `scheme_applications` (`decided_by`/`decided_at`, round 97), a resolved
-- support ticket carried no record of which staff account (crp/clf/admin)
-- actually handled it — any of `support_ticket_detail_page.dart`'s status
-- options could be set via the staff-only `PopupMenuButton` with no
-- attribution left behind at all. Real audit-trail gap, same completeness
-- bar already applied to Financial Records/Scheme Applications.
--
-- No additional column-lock helper is needed here the way loans/schemes
-- needed one: `support_tickets_update_staff`'s existing `using`/`with
-- check` is already unconditionally staff-only for every column on this
-- table (no member self-update branch exists at all, per `0013`), so
-- adding two more staff-settable columns doesn't introduce a new
-- escalation surface. The one thing worth pinning is that a staff account
-- can only ever attribute a resolution to *herself*, not misattribute it to
-- a different staff member — `resolved_by = auth.uid()` (or left null)
-- mirrors the same self-pin already used for `created_by`/`decided_by`
-- elsewhere.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.support_tickets add column if not exists resolved_by uuid references public.profiles (id);
alter table public.support_tickets add column if not exists resolved_at timestamptz;

drop policy if exists "support_tickets_update_staff" on public.support_tickets;

create policy "support_tickets_update_staff" on public.support_tickets
  for update using (
    is_staff()
  ) with check (
    is_staff()
    and (resolved_by is null or resolved_by = auth.uid())
  );
