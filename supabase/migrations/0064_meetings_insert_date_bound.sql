-- meetings_insert_leader_or_staff: bound how far in the past a leader can
-- insert a meeting, closing a real fabricated-history gap found during a
-- broad gap-hunting audit.
--
-- The policy only ever checked `shg_id`/`current_role()` — nothing
-- constrained `meeting_date` at all. `MeetingSchedulePage`'s date picker
-- (`firstDate: DateTime.now()`) is UX only, per this project's own standing
-- rule ("RLS in Postgres is authorization. Client-side role checks are UX
-- only."). `0038`'s original "a fabricated status/date is harmless"
-- reasoning is stale now that `TrendRepository`/`AnalyticsRepository`/
-- `ReportRepository` all key SHG health/attendance scores off
-- `meeting_date < today` (see `0042_meeting_cancel_and_attendance_lifecycle_guards.sql`,
-- which patched the CANCEL transition on this exact staleness but never
-- revisited INSERT).
--
-- Concrete exploit this closes: a leader could `POST /rest/v1/meetings`
-- directly with `meeting_date` set to 3 months ago, then insert
-- `meeting_attendance` rows marking her own SHG's real members present —
-- manufacturing a perfectly-attended historical meeting out of thin air,
-- retroactively inflating her SHG's attendance trend/health score ahead of
-- a CLF/bank review, with a fully legitimate-looking leader-authenticated
-- request.
--
-- A 7-day grace window (rather than requiring `meeting_date >= today`)
-- deliberately still allows the real, common case this app has to support:
-- a leader logging a meeting a few days after it actually happened because
-- she didn't have the app open/had no signal at the time — only blocks
-- fabricating something from materially further back than any plausible
-- "I'm logging this late" scenario.

drop policy if exists "meetings_insert_leader_or_staff" on public.meetings;

create policy "meetings_insert_leader_or_staff" on public.meetings
  for insert with check (
    ((shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff())
    and meeting_date >= (current_date - interval '7 days')
  );
