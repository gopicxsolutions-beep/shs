-- Gap-hunt iteration 30 (self-caught immediately after deploying 0125):
-- `public.profile_shg_id(p_member_id)` is NOT a general "look up this
-- member's SHG" helper — reading its actual definition:
--
--   select p.shg_id from public.profiles p
--   where p.id = p_member_id
--     and p.shg_id = (select me.shg_id from public.profiles me where me.id = auth.uid())
--
-- it only returns a value when the CALLER's OWN shg_id already equals the
-- target's — i.e. it's a same-SHG-peer check, not a membership lookup.
-- This is exactly right for the LEADER branches 0125 left untouched (a
-- leader's own shg_id is real and non-null, so this correctly answers "is
-- this member in MY same SHG"). But 0125's new STAFF-branch checks reused
-- the same function for crp/clf/admin callers — whose own `shg_id` is
-- ALWAYS null by this app's platform-wide-staff design (`updateUserRole()`
-- explicitly clears it on promotion). `null = m.shg_id` is never true, so
-- every one of 0125's staff-branch scope checks was unconditionally FALSE
-- for every staff caller, for every meeting — not just correctly blocking
-- cross-SHG forgery, but silently disabling the entire staff attendance-
-- recording and action-item-assignment features outright, including for
-- perfectly legitimate same-SHG oversight actions.
--
-- Caught immediately via this round's own live verification: the CRITICAL
-- cross-SHG-forgery negative test correctly failed, but the very next
-- positive-control test (a legitimate same-SHG staff insert, which should
-- have succeeded) failed with the identical RLS error — revealing the
-- staff branch was blocking everything, not just the exploit.
--
-- Fix: for the staff branches specifically, check membership directly
-- against `public.profiles` instead of the peer-scoped helper. This is
-- safe and correct here because `is_staff()` is already true in this
-- branch, and `profiles_select_self_shg_or_staff`'s own is_staff() clause
-- already grants a staff caller RLS-visibility into ANY profile row — so
-- this subquery genuinely sees the target row regardless of the caller's
-- own (null) shg_id, unlike `profile_shg_id()`.

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
        join public.profiles p on p.id = meeting_attendance.member_id and p.shg_id = m.shg_id
        where m.id = meeting_attendance.meeting_id
          and m.status <> 'cancelled'
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
          join public.profiles p on p.id = meeting_attendance.member_id and p.shg_id = m.shg_id
          where m.id = meeting_attendance.meeting_id
            and m.status <> 'cancelled'
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
          and (
            meeting_action_items.owner_id is null
            or exists (
              select 1 from public.profiles p
              where p.id = meeting_action_items.owner_id and p.shg_id = m.shg_id and p.is_active
            )
          )
      )
    )
  );
