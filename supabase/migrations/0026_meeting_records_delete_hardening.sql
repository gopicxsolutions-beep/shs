-- Systematic re-verification of round 13's DELETE-scope audit (0014), which
-- covered every table's DELETE policy but judged the whole meetings/
-- meeting_attendance/meeting_minutes family "Safe" purely on the grounds
-- that none of them are financial-ledger-style records ("Not a financial
-- record. Safe" / "not a financial-audit concern"). Re-deriving those three
-- verdicts specifically against the question this session's later rounds
-- (0014 itself, then 46/47) actually established as the real bar —
-- "could a non-admin actor use this DELETE to destroy an audit trail or
-- hide something, not just whether the row happens to hold money" — finds
-- 0014's dismissal doesn't hold up for any of the three, and the app itself
-- never exercises DELETE on any of them (grepped every `.delete()` call
-- site in `lib/repositories/*.dart`: the only one anywhere in the whole app
-- is `SchemeRepository.deleteScheme()`, admin-only, matching
-- `schemes_write_admin` — meetings/attendance/minutes are 100% REST-only
-- delete surface, exactly like every other gap this session has closed).
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1. meetings_write_leader_or_staff — a leader can DELETE an entire
--    'completed' meeting row for her own SHG, which CASCADES (0001's own
--    `on delete cascade` FKs) to permanently wipe that meeting's
--    `meeting_minutes` (the recorded "decisions") and every member's
--    `meeting_attendance` row in a single statement.
-- ─────────────────────────────────────────────────────────────────────────
-- 0014's verdict didn't consider the cascade at all — it reasoned only
-- about the `meetings` row itself ("a leader cancelling/removing her own
-- group's meeting is the intended feature"). But `MeetingRepository`
-- confirms cancelling is already done via `setStatus(id, 'cancelled')` (an
-- UPDATE) — DELETE is not used for that, or for anything else; there is no
-- status check in the policy either, so a leader can delete a meeting
-- regardless of whether it's 'upcoming' or already 'completed' with real
-- history attached. Concretely: a leader whose meeting's minutes recorded
-- an inconvenient decision (e.g. a vote to investigate a cashbook
-- discrepancy) or whose attendance roster shows a pattern of her own
-- absences, can delete that one `meetings` row and every downstream
-- record disappears with it, leaving no trace that the meeting — or its
-- minutes, or anyone's attendance at it — ever existed. This is the same
-- "financial/governance record that should never be hard-deletable except
-- by staff" shape 0014 already used to fix `savings_entries`/
-- `financial_ledger`, just reached via a cascade instead of a direct row
-- delete. Fix: split the single FOR ALL policy — leader keeps her existing,
-- actually-used ability to create and update (reschedule/cancel-via-status)
-- her own SHG's meetings; DELETE becomes staff-only.
drop policy if exists "meetings_write_leader_or_staff" on public.meetings;

create policy "meetings_insert_leader_or_staff" on public.meetings
  for insert with check (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

create policy "meetings_update_leader_or_staff" on public.meetings
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );

create policy "meetings_delete_staff" on public.meetings
  for delete using (public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- 2. meeting_attendance_self_or_leader — independent of the cascade above,
--    a member can delete her OWN attendance row directly (any status,
--    any of her own SHG's meetings), and a leader can delete ANY member's
--    attendance row in her own SHG directly — either erases an inconvenient
--    absence (or any) record without touching the parent meeting at all.
-- ─────────────────────────────────────────────────────────────────────────
-- The `using` clause (`member_id = auth.uid() or <leader-own-shg> or
-- is_staff()`) has been unchanged since 0002 — round 47's own fix (0024)
-- only tightened the `with check` (the self-check-in branch's meeting-SHG
-- scope for INSERT/UPDATE), never touched `using`, so this DELETE gap
-- survived that pass too. Attendance isn't cosmetic: both
-- `member_report_page.dart`/`shg_performance_report_page.dart` render
-- attendance-percentage as a tracked performance/compliance figure. A
-- member marked absent by her leader's roster (`markAttendance`, upsert)
-- can `DELETE /rest/v1/meeting_attendance?meeting_id=eq.<x>&member_id=eq.
-- <self>` to make that absence vanish from every report entirely (not just
-- flip a status flag — the row itself is gone), and a leader can do the
-- same for any other member's row in her own SHG, e.g. to cover up her own
-- poor turnout as leader or manufacture a cleaner attendance history ahead
-- of a CLF/bank review. Fix: same split — self/leader keep their existing,
-- actually-used INSERT/UPDATE (mark attendance) rights untouched; DELETE
-- becomes staff-only.
drop policy if exists "meeting_attendance_self_or_leader" on public.meeting_attendance;

create policy "meeting_attendance_insert_self_or_leader" on public.meeting_attendance
  for insert with check (
    (
      member_id = auth.uid()
      and exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.shg_id = public.current_shg_id()
      )
    )
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
    )
    or public.is_staff()
  );

create policy "meeting_attendance_update_self_or_leader" on public.meeting_attendance
  for update using (
    member_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  ) with check (
    (
      member_id = auth.uid()
      and exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.shg_id = public.current_shg_id()
      )
    )
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
    )
    or public.is_staff()
  );

create policy "meeting_attendance_delete_staff" on public.meeting_attendance
  for delete using (public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- 3. meeting_minutes_write_leader_or_staff — a leader can delete her own
--    SHG's recorded minutes outright, independent of the meetings cascade.
-- ─────────────────────────────────────────────────────────────────────────
-- `meeting_minutes.decisions` is literally this schema's durable record of
-- what a meeting decided — `MeetingRepository.saveMinutes()` only ever
-- INSERTs (each save creates a new row; `fetchLatestMinutes` reads the most
-- recent by `created_at`), so minutes are already append-only BY THE APP'S
-- OWN DESIGN — the DELETE branch of this FOR ALL policy is pure unused
-- REST-only surface directly contradicting that append-only intent. A
-- leader could delete a minutes row recording a decision she'd rather not
-- have on the books (e.g. a vote to escalate a cashbook discrepancy, or
-- minutes noting her own conduct was questioned) with nothing left behind.
-- Fix: same split — leader/staff keep the actually-used ability to record
-- new minutes (and, since the policy already allowed it, correct an
-- existing entry); DELETE becomes staff-only.
drop policy if exists "meeting_minutes_write_leader_or_staff" on public.meeting_minutes;

create policy "meeting_minutes_insert_leader_or_staff" on public.meeting_minutes
  for insert with check (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_minutes.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    ) or public.is_staff()
  );

create policy "meeting_minutes_update_leader_or_staff" on public.meeting_minutes
  for update using (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_minutes.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    ) or public.is_staff()
  ) with check (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_minutes.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    ) or public.is_staff()
  );

create policy "meeting_minutes_delete_staff" on public.meeting_minutes
  for delete using (public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- NOT changed (re-derived, still correct as of this pass):
--   meeting_action_items_write_related — 0015/0024 already explicitly
--     disclosed this table as lower-stakes (nullable/optional to-do
--     assignment, not populated by the app today, no financial/attendance/
--     audit-trail weight) and left its `owner_id` cross-SHG gap unfixed on
--     that basis; the same reasoning applies to its DELETE branch, so it's
--     left untouched here rather than re-litigated.
--   shg_documents_write_leader_or_staff — 0014 judged this genuinely
--     intended leader-managed CRUD (removing an expired/superseded
--     document from her own SHG's list), not an append-only audit trail
--     the way minutes/attendance are; not revisited.
--   Every other DELETE policy in the schema (shgs/profiles/loans/
--   savings_entries/financial_ledger/payments already staff-or-admin-only;
--   marketplace_orders/loan_payments/scheme_applications/support_tickets/
--   support_messages/ai_advisor_logs/audit_log/shg_join_requests have no
--   delete policy at all) re-confirmed unchanged and correct.
-- ─────────────────────────────────────────────────────────────────────────
