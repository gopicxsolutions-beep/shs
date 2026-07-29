-- Gap-hunt iteration 33: 2 more fixes from this round's dogfooding pass and
-- the Announcements/Profile audit.
--
-- 1. [HIGH] `meetings_update_leader_or_staff`'s staff branch cancel-guard
-- (added in migration 0129, `status <> 'cancelled' or meeting_date >=
-- current_date`) is evaluated against the NEW row's `meeting_date` — but
-- the staff branch never locks `meeting_date` to its original value (only
-- bounds the new value to `>= current_date - 7 days`). So a staff account
-- can cancel a genuinely historical meeting AND simultaneously move its
-- `meeting_date` into the future in the SAME update, satisfying the
-- guard's "it's a future meeting" disjunct while relocating/effectively
-- erasing the original historical record (and its real recorded
-- attendance) from any past-window health-score calculation. Live-verified
-- by this round's dogfooding pass: a 3-day-old `completed` meeting with
-- attendance was cancelled AND moved to a future date in one UPDATE, 1 row
-- affected, no error. Fixed by evaluating the guard against the meeting's
-- OWN ORIGINAL `meeting_date` (via `meetings_locked_fields`) instead of the
-- submitted new value — a staff account can still independently correct a
-- near-term meeting's date (unchanged capability), but can no longer use a
-- simultaneous date change to launder a retroactive cancellation of an
-- already-past meeting.
--
-- 2. [LOW] `announcement_reads_delete_self` (0090) was deliberately left
-- without the `profile_is_active` gate its sibling insert/update policies
-- both have, judged "low stakes" at the time. Live-verified by this
-- round's Announcements audit: a deactivated member can still delete her
-- own read-receipt row, making an already-read announcement look unread
-- again for herself — no cross-user impact, but a real, currently-live
-- inconsistency with this same table's own insert/update policies. Fixed
-- by adding the same gate.

drop policy if exists "meetings_update_leader_or_staff" on public.meetings;

create policy "meetings_update_leader_or_staff" on public.meetings
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (
      public.is_staff()
      and (
        status <> 'cancelled'
        or (select f.meeting_date from public.meetings_locked_fields(meetings.id) f) >= current_date
      )
      and shg_id = (select f.shg_id from public.meetings_locked_fields(meetings.id) f)
      and meeting_date >= (current_date - interval '7 days')
    )
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

drop policy if exists "announcement_reads_delete_self" on public.announcement_reads;
create policy "announcement_reads_delete_self" on public.announcement_reads
  for delete using (member_id = auth.uid() and public.profile_is_active(member_id));
