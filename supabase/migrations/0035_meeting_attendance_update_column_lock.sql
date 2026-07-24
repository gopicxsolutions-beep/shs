-- Dedicated deep-dive on meeting ATTENDANCE MARKING (leader's roster page +
-- member self-check-in), applying the same "full column-by-column
-- re-derivation" rigor round 81 (0034) just applied to `savings_entries`'s
-- UPDATE policy, to the OTHER table that directly feeds `avg_attendance_pct`
-- (used elsewhere for SHG grading/health scores). 0024/0026 already fixed
-- this table's `with check` to require `meeting_id`/`member_id` resolve to
-- SOME meeting/member combination inside the caller's own SHG (closing the
-- cross-SHG and phantom-member gaps) — but neither pass asked round 81's
-- exact follow-up question: is the row's identity (which meeting, which
-- member) LOCKED TO ITS ORIGINAL STORED VALUE on UPDATE, or merely
-- re-validated against "somewhere in my own SHG" on every write?
--
-- Columns (0001_init_schema.sql): id, meeting_id, member_id, present,
-- marked_at. `meeting_attendance_update_self_or_leader`'s `with check`
-- (0026):
--   (member_id = auth.uid() and exists(...meeting in caller's own SHG...))
--   or exists(...meeting in caller's own SHG, current_role() = 'leader',
--             profile_shg_id(member_id) = m.shg_id...)
--   or is_staff()
-- Neither branch compares the NEW `meeting_id`/`member_id` to the row's
-- EXISTING stored values — both only require the new destination to be
-- "some meeting in my own SHG" (leader branch) / "some meeting in my own
-- SHG, with member_id fixed to myself" (self branch, for meeting_id only).
-- `MeetingRepository.markAttendance()` (the only call site anywhere in
-- `lib/` that writes this table — grepped) always `.upsert()`s with
-- `onConflict: 'meeting_id,member_id'`: for an existing row, this is
-- ALWAYS an update to `present`/`marked_at` only, keying off the exact same
-- `(meeting_id, member_id)` pair — the app itself never issues an UPDATE
-- that changes either column on an existing row. So a direct REST
-- `PATCH .../meeting_attendance?id=eq.<row>` in place of the app's own call
-- opens two concrete, previously-uncovered exploits:
--
-- 1. Leader identity-hijack: a leader can take an EXISTING attendance row
--    (say, meeting M / member Bob / present=true) and retarget its
--    `member_id` to a different member of her own SHG (Alice) via
--    `PATCH ... {member_id: <alice>}` — `using` only re-checks the OLD
--    row's meeting is hers, `with check`'s leader branch only re-checks the
--    NEW member_id resolves to a member of that same SHG, not that it
--    matches what was already stored. Net effect: Bob's real "present"
--    record silently vanishes (retargeted, not duplicated) and Alice gets
--    credited with it instead — inflating one member's individual
--    attendance history at another's expense, with no audit trail (looks
--    identical to an ordinary `markAttendance` call). The same leader
--    branch never locks `meeting_id` either, so a leader can equally slide
--    an existing "present" row from one of her own SHG's meetings to
--    another, directly manipulating the per-meeting present-count
--    `AnalyticsRepository`/`ReportRepository` aggregate by `meeting_id`
--    (confirmed: `analytics_repository.dart`'s SHG-attendance query groups
--    exactly `meeting_attendance.present`/`meeting_id` this way) — e.g.
--    moving attendance INTO a meeting under CLF/bank review to inflate its
--    look, or OUT of one to bury a poorly-attended session.
-- 2. Member self-service bypass of round 80's fix: the self branch already
--    pins `member_id = auth.uid()` on both old and new rows (so a member
--    can't hijack anyone else's row), but never pins `meeting_id`. Round 80
--    (0-day-window fix, `meeting_qr_page.dart`) closed the ability to
--    self-check-in early via `.upsert()`-as-INSERT for a meeting that
--    hasn't happened yet, by filtering the QR page's "next meeting" picker
--    to `isScheduledToday`. But that fix only touches which meeting the
--    app's own INSERT-shaped upsert targets — it does nothing to stop a
--    member who already has ANY attendance row (e.g. a genuine check-in
--    from a past meeting) from directly `PATCH`-ing that row's `meeting_id`
--    to point at a brand-new, weeks-out meeting instead, self-marking
--    "present" for it via UPDATE — the exact fraud round 80 set out to
--    prevent, just reached one HTTP verb over. Round 80 deliberately
--    scoped its fix to the QR page only and explicitly left this page/table
--    untouched on the theory that "leader's own roster, explicit per-member
--    marking" isn't a self-service write trigger — that reasoning is about
--    the LEADER page's UI, not about this RLS gap in the self-branch of the
--    UPDATE policy, which is reachable by any member directly via REST
--    regardless of which UI exists; not the same question, so not
--    re-litigating round 80's verdict, just closing a gap it didn't cover.
--
-- `present`/`marked_at` are deliberately left OUT of the lock — they are
-- the entire point of this policy's legitimate write (`present` is quite
-- literally what "marking attendance" means, and `marked_at` is
-- write-only bookkeeping metadata never read back anywhere in `lib/`
-- (grepped), matching the 0023/0024 precedent for leaving low-stakes,
-- single-owner-scoped timestamp columns unlocked).
--
-- Uses the same security-definer locked-fields pattern already established
-- for `loans`/`marketplace_orders`/`announcements`/`savings_entries`
-- (0019/0018/0024/0034) to read the row's pre-image without the
-- self-referencing-subquery recursion that broke `loans`/`marketplace_orders`
-- in rounds 36/37 (0018/0019).

create or replace function public.meeting_attendance_locked_fields(p_id uuid)
returns table (meeting_id uuid, member_id uuid)
language sql
security definer
stable
set search_path = public
as $$
  select ma.meeting_id, ma.member_id
  from public.meeting_attendance ma
  where ma.id = p_id
    and (
      ma.member_id = auth.uid()
      or exists (
        select 1 from public.meetings m
        where m.id = ma.meeting_id and m.shg_id = public.current_shg_id()
      )
      or public.is_staff()
    );
$$;

revoke all on function public.meeting_attendance_locked_fields(uuid) from public;
grant execute on function public.meeting_attendance_locked_fields(uuid) to authenticated;

drop policy if exists "meeting_attendance_update_self_or_leader" on public.meeting_attendance;

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
    public.is_staff()
    or (
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
    ) and (
      meeting_id = (select f.meeting_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
      and member_id = (select f.member_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Re-derived and confirmed CLEAN (not re-litigating round 68's verdict,
-- but retracing the concurrent-writer/idempotency question fresh against
-- THIS change): two leaders (or a leader and a self-checking-in member)
-- both marking the same `(meeting_id, member_id)` pair at once still only
-- ever race via `upsert`, which never touches `meeting_id`/`member_id`
-- (they're the conflict key, always sent as-is) — this migration's new
-- lock only constrains a genuinely different write shape (retargeting an
-- EXISTING row's identity columns via UPDATE), so it changes nothing about
-- round 68's "genuinely idempotent, not a real double-effect" finding for
-- the toggle-shape concurrent write.
--
-- Also re-confirmed unchanged and still correct:
--   - Cross-SHG marking (item 2 of this round's brief): both INSERT branches
--     (0026) already require the target `meeting_id` resolve to a meeting
--     whose `shg_id = current_shg_id()` — a leader/member cannot write
--     attendance for a meeting belonging to a different SHG, insert or
--     update.
--   - Phantom-member marking (item 3): the leader branch's
--     `profile_shg_id(member_id) = m.shg_id` check (0024/0026, preserved
--     here) already rejects any `member_id` that isn't a real profile
--     inside that same SHG on both INSERT and UPDATE.
--   - Bulk "mark all present" correctness (item 5): `meeting_attendance_
--     page.dart` has no batch-write affordance at all — every roster row is
--     an independently-guarded, independently-error-handled `Switch`
--     (`_updating` set keyed per member id, its own try/catch/snackbar) —
--     there is no single "mark all" action that could partially fail across
--     multiple members in one silent operation.
--   - Leader-facing time-window (item 4): round 80 (0-day-window fix)
--     explicitly and deliberately scoped its fix to the member self-check-in
--     QR page only, reasoning the leader's own roster page is "a legitimate
--     future-looking display, not a self-service write trigger" — re-traced
--     fresh here and still holds: marking a future meeting's roster from
--     the leader's own page requires the leader's own authenticated
--     action against her own SHG's data, the same trust level as any other
--     leader-initiated write in this schema, not a new unsupervised gap.
-- ─────────────────────────────────────────────────────────────────────────
