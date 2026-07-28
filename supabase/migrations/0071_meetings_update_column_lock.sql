-- meetings: UPDATE has no column lock at all — a leader can change
-- `meeting_date` in the SAME statement as a `status` transition, defeating
-- both of 0042's own guards in one PATCH.
--
-- `meetings_update_leader_or_staff`'s `with check` (0042) added `status <>
-- 'cancelled' or meeting_date >= current_date` specifically so a leader
-- couldn't retroactively cancel a months-old meeting with real attendance
-- to erase it from avg_attendance_pct/health-score. But that condition
-- evaluates the SUBMITTED (new) row, not the meeting's actual stored date
-- — `update meetings set status='cancelled', meeting_date=current_date
-- where id=<3-months-old-meeting>` passes trivially (new.meeting_date >=
-- current_date is true), silently reopening exactly what 0042 closed, one
-- write-verb later. The same missing lock separately reopens 0064's
-- backdating guard (which only bounds meeting_date on INSERT): a leader
-- can insert a meeting today, mark full attendance via the roster page (no
-- date restriction there — intentional, 0035/0042), then PATCH
-- meeting_date back several months, fabricating a perfectly-attended
-- historical meeting. And independently of `status` entirely, since
-- `TrendRepository`/`ReportRepository`/`AnalyticsRepository`'s attendance
-- windows all filter directly on `meeting_date`, a leader can push a
-- poorly-attended meeting's date FORWARD to silently drop it out of the
-- rolling window with no cancellation at all.
--
-- `MeetingRepository` has no "edit meeting" method whatsoever — `schedule()`
-- (INSERT) and `setStatus()` (the app's only UPDATE, which only ever sends
-- `{'status': status}`) are the entire write surface; there is no
-- reschedule/edit-details feature in the UI at all. So the correct fix,
-- identical in shape to `marketplace_orders_update_seller_or_staff` (0013)
-- and `loans_update_...` locking every column except the one the app
-- actually means to change: lock every column except `status` on UPDATE
-- for non-staff. This closes all three exploits above in one change — once
-- `meeting_date` (and every other column) is pinned to its stored value,
-- the cancel-guard's `meeting_date >= current_date` check necessarily
-- refers to the meeting's real original date, since new.meeting_date ==
-- old.meeting_date is now enforced. `is_staff()` keeps its existing
-- unconditional bypass (an admin/CRP/CLF correction, e.g. fixing a typo'd
-- venue on an old meeting, is a different trust level — same precedent as
-- every other locked-fields policy in this schema).

create or replace function public.meetings_locked_fields(p_id uuid)
returns table (shg_id uuid, meeting_date date, meeting_time text, venue text, agenda text)
language sql
security definer
stable
set search_path = public
as $$
  select m.shg_id, m.meeting_date, m.meeting_time, m.venue, m.agenda
  from public.meetings m
  where m.id = p_id;
$$;

revoke all on function public.meetings_locked_fields(uuid) from public;
grant execute on function public.meetings_locked_fields(uuid) to authenticated;

drop policy if exists "meetings_update_leader_or_staff" on public.meetings;

create policy "meetings_update_leader_or_staff" on public.meetings
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    public.is_staff()
    or (
      shg_id = public.current_shg_id()
      and public.current_role() = 'leader'
      and (status <> 'cancelled' or meeting_date >= current_date)
      and shg_id = (select f.shg_id from public.meetings_locked_fields(meetings.id) f)
      and meeting_date is not distinct from (select f.meeting_date from public.meetings_locked_fields(meetings.id) f)
      and meeting_time is not distinct from (select f.meeting_time from public.meetings_locked_fields(meetings.id) f)
      and venue is not distinct from (select f.venue from public.meetings_locked_fields(meetings.id) f)
      and agenda is not distinct from (select f.agenda from public.meetings_locked_fields(meetings.id) f)
    )
  );
