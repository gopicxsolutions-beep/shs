-- Gap-hunt iteration 32: dogfooding pass over iteration 31 found no new
-- gaps in the scheme_applications/attendance-rate fixes (both re-verified
-- live and holding), but a fresh Meetings/Livelihood audit found 2 more
-- real live-exploitable gaps in the recurring "is_staff() branch left wide
-- open" shape this codebase keeps rediscovering.
--
-- 1. [CRITICAL] `livelihood_update_self_leader_or_staff`'s top-level OR had
-- TWO branches: a fully unrestricted staff-editing-another's-row branch
-- (`is_staff() and member_id <> auth.uid() and profile_is_active(member_id)`
-- — no column lock, no status-transition limit, no revenue-freeze rule at
-- all), and a second, fully-correct branch that ALREADY covers is_staff()
-- as one of its own three permitted actors alongside every locked-field/
-- transition/revenue-freeze check. The first branch was pure dead weight
-- that turned into a hole: since is_staff() is already one of the second
-- branch's own permitted actors, the first branch never legitimately
-- widened who could act — it only widened what an already-permitted staff
-- actor could get away with, IF the second branch's disjunct is where
-- staff should always be evaluated instead. Live-verified (rolled back): as
-- a crp, retargeted a real activity's shg_id AND member_id to different
-- values, its activity_type, and set investment/revenue to fabricated
-- figures with status='completed', in one UPDATE — 1 row affected, no
-- error. Fix: delete the first (redundant, unrestricted) branch entirely —
-- staff now only ever update via the second branch, which was always
-- correct and already grants staff full authority subject to every lock.
--
-- 2. [HIGH] `meetings_update_leader_or_staff`'s staff branch (added in
-- migration 0110 alongside the leader branch's `status <> 'cancelled' or
-- meeting_date >= current_date` cancel-guard) never got that same guard —
-- only the leader branch has it. Live-verified (rolled back): as a crp, set
-- `status = 'cancelled'` on a real 3-day-old `completed` meeting with real
-- recorded attendance — 1 row affected, no error. This reopens, for staff,
-- the exact "retroactively cancel a well-attended historical meeting to
-- erase it from health scores" exploit migration 0042 closed for leaders.
-- Fix: add the identical cancel-guard to the staff branch.

drop policy if exists "livelihood_update_self_leader_or_staff" on public.livelihood_activities;

create policy "livelihood_update_self_leader_or_staff" on public.livelihood_activities
  for update using (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  )
  with check (
    (member_id = auth.uid() or (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff())
    and public.profile_is_active(member_id)
    and shg_id = (select f.shg_id from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
    and member_id = (select f.member_id from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
    and activity_type = (select f.activity_type from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
    and description is not distinct from (select f.description from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
    and investment is not distinct from (select f.investment from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
    and created_at = (select f.created_at from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
    and abs(
      array_position(array['planned','active','completed'], status)
      - array_position(array['planned','active','completed'], (select f.status from public.livelihood_activities_locked_fields(livelihood_activities.id) f))
    ) <= 1
    and (
      (select f.status from public.livelihood_activities_locked_fields(livelihood_activities.id) f) <> 'completed'
      or revenue = (select f.revenue from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
    )
  );

drop policy if exists "meetings_update_leader_or_staff" on public.meetings;

create policy "meetings_update_leader_or_staff" on public.meetings
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (
      public.is_staff()
      and (status <> 'cancelled' or meeting_date >= current_date)
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
