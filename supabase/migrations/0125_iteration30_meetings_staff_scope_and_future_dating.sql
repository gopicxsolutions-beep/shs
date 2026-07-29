-- Gap-hunt iteration 30: Meetings/Attendance full sweep, 4 findings closed.
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1. [CRITICAL] `meeting_attendance_insert_self_or_leader`'s `is_staff()`
--    branch was a bare `(is_staff() and profile_is_active(member_id))` —
--    unlike the self branch (requires same-SHG + today) and the leader
--    branch (requires `profile_shg_id(member_id) = m.shg_id`), the staff
--    branch never checked that `member_id` actually belongs to the
--    MEETING's own SHG at all. Live-verified: a real crp inserted a
--    present=true attendance row for one SHG's meeting, naming a real
--    active member of a COMPLETELY DIFFERENT SHG as `member_id` —
--    succeeded. `TrendRepository.attendanceRate()` (feeding the CRP/CLF
--    health score and SHG performance reports) sums raw
--    `meeting_attendance.present` rows per `meeting_id` with no membership
--    check, so a forged row directly inflates the TARGETED SHG's
--    attendance stat using a member who was never in it. Same bug class
--    this exact table's UPDATE path and `meetings` itself already had
--    fixed (0110) — never closed on this table's INSERT.
--
-- 2. [HIGH] Neither the leader nor the staff branch on INSERT/UPDATE
--    checked the meeting's own date — only the self-check-in branch
--    required `meeting_date = today`. A leader (or staff) could mark
--    attendance for a meeting dated days in the future — reachable through
--    the shipped UI, since `meeting_attendance_page.dart`'s picker offers
--    any non-cancelled upcoming meeting, not just today's. Once that date
--    passes, the row is indistinguishable from a genuine same-day mark.
--    Added `m.meeting_date <= (IST today)` to both branches.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meeting_attendance_insert_self_or_leader" on public.meeting_attendance;

create policy "meeting_attendance_insert_self_or_leader" on public.meeting_attendance
  for insert with check (
    (
      member_id = auth.uid()
      and exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.shg_id = public.current_shg_id()
          and m.status <> 'cancelled'
          and m.meeting_date = (now() at time zone 'Asia/Kolkata')::date
      )
    )
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and m.status <> 'cancelled'
        and public.current_role() = 'leader'
        and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
        and public.profile_is_active(meeting_attendance.member_id)
        and m.meeting_date <= (now() at time zone 'Asia/Kolkata')::date
    )
    or (
      public.is_staff()
      and public.profile_is_active(meeting_attendance.member_id)
      and exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.status <> 'cancelled'
          and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
          and m.meeting_date <= (now() at time zone 'Asia/Kolkata')::date
      )
    )
  );

drop policy if exists "meeting_attendance_update_self_or_leader" on public.meeting_attendance;

create policy "meeting_attendance_update_self_or_leader" on public.meeting_attendance
  for update using (
    member_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id and m.shg_id = public.current_shg_id() and m.status <> 'cancelled' and public.current_role() = 'leader'
    )
    or public.is_staff()
  )
  with check (
    (
      (
        public.is_staff()
        and public.profile_is_active(meeting_attendance.member_id)
        and exists (
          select 1 from public.meetings m
          where m.id = meeting_attendance.meeting_id
            and m.status <> 'cancelled'
            and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
            and m.meeting_date <= (now() at time zone 'Asia/Kolkata')::date
        )
      )
      or (
        member_id = auth.uid()
        and exists (
          select 1 from public.meetings m
          where m.id = meeting_attendance.meeting_id
            and m.shg_id = public.current_shg_id()
            and m.status <> 'cancelled'
            and m.meeting_date = (now() at time zone 'Asia/Kolkata')::date
        )
      )
      or exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.shg_id = public.current_shg_id()
          and m.status <> 'cancelled'
          and public.current_role() = 'leader'
          and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
          and public.profile_is_active(meeting_attendance.member_id)
          and m.meeting_date <= (now() at time zone 'Asia/Kolkata')::date
      )
    )
    and meeting_id = (select f.meeting_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
    and member_id = (select f.member_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. [MEDIUM/HIGH] `meeting_action_items_insert_leader_or_staff`'s
--    `is_staff()` disjunct had zero `owner_id` validation, unlike the
--    leader branch two clauses earlier in the same policy (which requires
--    `owner_id` to be null or a same-SHG active member). Live-verified: a
--    real crp inserted an action item on one SHG's meeting with `owner_id`
--    set to a real active member of a different SHG — succeeded. Added the
--    same scope check to the staff branch.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meeting_action_items_insert_leader_or_staff" on public.meeting_action_items;

create policy "meeting_action_items_insert_leader_or_staff" on public.meeting_action_items
  for insert with check (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and (meeting_action_items.owner_id is null or (public.profile_shg_id(meeting_action_items.owner_id) = m.shg_id and public.profile_is_active(meeting_action_items.owner_id)))
    )
    or (
      public.is_staff()
      and exists (
        select 1 from public.meetings m
        where m.id = meeting_action_items.meeting_id
          and (meeting_action_items.owner_id is null or (public.profile_shg_id(meeting_action_items.owner_id) = m.shg_id and public.profile_is_active(meeting_action_items.owner_id)))
      )
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 4. [MEDIUM] `meeting_action_items_delete_related`'s `owner_id =
--    auth.uid()` branch was judged low-stakes when written (0026/0047,
--    on the premise that owner assignment "wasn't populated by the app"
--    yet) — that premise is now stale: a real "Assign to" roster picker
--    exists and is used. Grepped every `.delete()` call site for action
--    items in `lib/repositories/meeting_repository.dart` — zero exist, so
--    this branch is a pure REST-only surface with no legitimate app
--    feature depending on it. Dropped, consistent with this session's
--    established precedent of retiring dead-but-permissive branches
--    (e.g. `loan_payments_insert_related`, migration 0110).
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meeting_action_items_delete_related" on public.meeting_action_items;

create policy "meeting_action_items_delete_related" on public.meeting_action_items
  for delete using (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id and m.shg_id = public.current_shg_id() and public.current_role() = 'leader'
    )
    or (public.is_staff() and owner_id is distinct from auth.uid())
  );
