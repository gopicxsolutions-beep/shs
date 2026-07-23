-- Adversarial-review follow-up on `meeting_detail_page.dart`'s "Cancel
-- Meeting" action and its interaction with attendance marking. Three
-- findings, closed together since all three are the same underlying shape:
-- "cancelling a meeting retroactively erases or corrupts real attendance
-- history", reached via a different write path each time.
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1. `meetings_update_leader_or_staff` (0026) lets a leader flip her own
--    SHG's meeting to `status = 'cancelled'` regardless of `meeting_date`.
--    The ONLY UPDATE the app ever issues against `meetings` is exactly this
--    (`MeetingRepository.setStatus()` — single call site, only ever called
--    with `'cancelled'`, never `'completed'`). 0038's own re-derivation
--    dismissed `meetings`' status/meeting_date starting values as "low
--    stakes" on the reasoning that "nothing downstream trusts a fabricated
--    'completed'/'cancelled' row as anyone else's compliance record" — true
--    when written, but no longer: `ReportRepository`/`TrendRepository`/
--    `AnalyticsRepository`'s completed-meeting and attendance-percentage
--    queries all now key off exactly `.neq('status', 'cancelled')` combined
--    with `meeting_date < today` (nothing ever advances a meeting to
--    'completed', so "has this meeting happened" is inferred purely from
--    the date, and "was it cancelled after the fact" purely from `status`).
--    That makes `status = 'cancelled'` a genuine, trusted signal today, and
--    this policy still lets a leader set it on a meeting from months ago
--    with real recorded attendance — permanently and retroactively
--    excluding that meeting from her own SHG's completed-meeting count /
--    avg_attendance_pct / attendance trend / CRP health score, a one-tap
--    way to erase inconvenient real history. `meeting_detail_page.dart` was
--    fixed in the same round to stop OFFERING this action once a meeting
--    has passed (`!meeting.hasPassed` added to the gate alongside the
--    existing `status == 'upcoming'` check) — but that is UI-only; nothing
--    stopped a direct `PATCH /rest/v1/meetings?id=eq.<x>` from doing it
--    anyway. Fix: the 'cancelled' transition specifically (not any other
--    update — a leader can still freely correct e.g. a typo'd venue on any
--    of her SHG's meetings, any date) additionally requires `meeting_date
--    >= current_date`. `is_staff()` keeps its existing unconditional
--    bypass, same precedent as every other policy in this schema (an
--    admin/CRP/CLF correction is a different trust level).
--
-- 2/3. `meeting_attendance_insert_self_or_leader` / `_update_self_or_leader`
--    (0026, `with check` re-derived again in 0035 for the locked-fields
--    fix) never check the target meeting's own `status` at all — a leader
--    (or a self-checking-in member) can insert/update an attendance row for
--    a meeting that is already `'cancelled'`. `meeting_attendance_page.dart`
--    only used its upcoming-and-not-passed check to choose the picker's
--    *default* selection, never to restrict which meetings were selectable
--    at all — a leader could pick an already-cancelled meeting from the
--    dropdown and flip its attendance switches after the fact, writing
--    fresh `meeting_attendance` rows tied to a cancelled meeting, visibly
--    inconsistent with that meeting's own detail page (a red "cancelled"
--    badge sitting directly above a live, freshly-editable roster). That
--    picker is fixed in the same round to exclude cancelled meetings
--    entirely, and `MeetingRepository.markAttendance()` now re-derives the
--    meeting's own status via `fetchById` and refuses to write for one that
--    is cancelled — but both of those are still client-side UX, not the
--    actual authorization boundary (a direct REST call bypasses both). Fix:
--    require the target meeting's `status <> 'cancelled'` in both INSERT
--    and UPDATE `with check`, and in the leader branch of UPDATE's `using`
--    (so a leader can't even select an existing row on a cancelled meeting
--    as an UPDATE target) — `is_staff()` keeps its unconditional bypass.
--    The self branch's own `using` clause (`member_id = auth.uid()` alone,
--    with no join to `meetings` at all) is a separate, pre-existing gap;
--    not re-litigated here — out of scope for these three findings.
-- ─────────────────────────────────────────────────────────────────────────

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
    )
  );

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
      )
    )
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and m.status <> 'cancelled'
        and public.current_role() = 'leader'
        and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
    )
    or public.is_staff()
  );

drop policy if exists "meeting_attendance_update_self_or_leader" on public.meeting_attendance;

create policy "meeting_attendance_update_self_or_leader" on public.meeting_attendance
  for update using (
    member_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and m.status <> 'cancelled'
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  ) with check (
    public.is_staff()
    or (
      (
        member_id = auth.uid()
        and exists (
          select 1 from public.meetings m
          where m.id = meeting_attendance.meeting_id
            and m.shg_id = public.current_shg_id()
            and m.status <> 'cancelled'
        )
      )
      or exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.shg_id = public.current_shg_id()
          and m.status <> 'cancelled'
          and public.current_role() = 'leader'
          and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
      )
    ) and (
      meeting_id = (select f.meeting_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
      and member_id = (select f.member_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Re-confirmed unchanged and still correct: `meeting_attendance_select_
-- related`, `meeting_attendance_delete_staff`, `meetings_insert_leader_or_
-- staff`, `meetings_delete_staff` are untouched by this migration — none of
-- the three findings above concern SELECT, DELETE, or INSERT on `meetings`
-- (a leader creating a new meeting with a backdated date/pre-set status is
-- a different, not-yet-observed attack shape, out of scope for this round).
-- ─────────────────────────────────────────────────────────────────────────
