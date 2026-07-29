-- Gap-hunt iteration 25 (round 198): 4 parallel audits (dogfood round 197,
-- Meetings/Attendance/Minutes, Training/Quiz/Certification, Support
-- Tickets + Payments). This migration closes every RLS/backend gap found.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [CRITICAL] `meeting_attendance_update_self_or_leader`'s `is_staff()`
--    branch was a fully independent top-level `or` in the `with check`,
--    never ANDed with the locked-fields clause (`meeting_attendance_
--    locked_fields`, added by 0035 specifically to stop a leader/self
--    retargeting an existing row's `meeting_id`/`member_id`). Any staff
--    account could PATCH an existing attendance row and freely rewrite
--    both `meeting_id` and `member_id` to any meeting/any active member
--    platform-wide — inflate one member's attendance at another's expense,
--    or move a row between meetings/SHGs, corrupting `avg_attendance_pct`
--    and every CRP/CLF health score computed from it (a live self-dealing
--    surface: CRPs are themselves graded on the SHGs they supervise).
--    Fixed by ANDing the locked-fields check onto the staff branch too,
--    mirroring the exact fix 0104 already applied to `savings_update_
--    leader_or_staff`/`payments_update_staff` for the same bug class.
-- ─────────────────────────────────────────────────────────────────────────

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
    (
      (public.is_staff() and public.profile_is_active(meeting_attendance.member_id))
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
      )
    ) and (
      meeting_id = (select f.meeting_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
      and member_id = (select f.member_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. [HIGH] `meetings_update_leader_or_staff`'s `is_staff()` branch was a
--    bare, unconditional bypass of `meetings_locked_fields` (0071) — a
--    staff account could PATCH any meeting row and rewrite `shg_id`
--    (reassign it to a different SHG, something no branch has ever
--    permitted), or `meeting_date` to any value with no bound at all,
--    reopening the exact backdating attack 0064 closed for INSERT (a
--    leader fabricating perfect historical attendance), just reachable via
--    a staff account through UPDATE instead. Fixed: `shg_id` is now locked
--    for staff too (no legitimate reason to ever reassign a meeting's
--    SHG), and `meeting_date` is bounded to the same 7-day grace window
--    0064 already established for INSERT — a staff correction of a
--    typo'd/near-term date remains possible, fabricating a materially
--    backdated historical record does not.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meetings_update_leader_or_staff" on public.meetings;

create policy "meetings_update_leader_or_staff" on public.meetings
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (
      public.is_staff()
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

-- ─────────────────────────────────────────────────────────────────────────
-- 3. [LOW, same repeating pattern] `meeting_action_items_delete_related`'s
--    `is_staff()` branch had no `owner_id <> auth.uid()` self-exclusion,
--    unlike its sibling `meeting_attendance_delete_staff` (0104). Currently
--    inert (staff is never assignable via the "Assign to" roster picker,
--    which only lists real SHG members), but closing it for consistency
--    with every other staff-DELETE branch in this schema rather than
--    leaving one silently unguarded.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meeting_action_items_delete_related" on public.meeting_action_items;

create policy "meeting_action_items_delete_related" on public.meeting_action_items
  for delete using (
    owner_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    )
    or (public.is_staff() and owner_id is distinct from auth.uid())
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 4. [HIGH] `course_progress_write_self_or_staff` was a single `for all`
--    policy — its four rounds of hardening (0051/0091/0106/0107) all
--    tightened `with check`, which Postgres never applies to DELETE, only
--    `using`. `using` has read `member_id = auth.uid() or is_staff()`
--    since 0002, completely unguarded for DELETE: any staff account could
--    erase another member's earned `certified=true`/`completed_on` row
--    outright via direct REST, with no self-exclusion, no audit trail,
--    feeding straight into the federation-wide training-adoption stat.
--    Grep confirms zero legitimate call sites anywhere in `lib/` ever
--    delete a `course_progress` row (self or other) — split the single
--    `for all` policy into explicit per-command policies, preserving the
--    existing SELECT/INSERT/UPDATE behavior unchanged, and add no DELETE
--    policy at all (RLS defaults to deny), matching this session's
--    established precedent of retiring an unused, exploitable-only write
--    path rather than patching it.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "course_progress_write_self_or_staff" on public.course_progress;

create policy "course_progress_select_self_or_staff" on public.course_progress
  for select using (member_id = auth.uid() or public.is_staff());

create policy "course_progress_insert_self_or_staff" on public.course_progress
  for insert with check (
    (
      public.is_staff()
      and profile_is_active(member_id)
      and member_id <> auth.uid()
      and certified is not distinct from coalesce((select f.certified from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f), false)
      and completed_on is not distinct from (select f.completed_on from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f)
    )
    or (
      member_id = auth.uid()
      and profile_is_active(member_id)
      and certified = coalesce((select f.certified from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f), false)
      and completed_on is not distinct from (select f.completed_on from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f)
    )
  );

create policy "course_progress_update_self_or_staff" on public.course_progress
  for update using (member_id = auth.uid() or public.is_staff())
  with check (
    (
      public.is_staff()
      and profile_is_active(member_id)
      and member_id <> auth.uid()
      and certified is not distinct from coalesce((select f.certified from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f), false)
      and completed_on is not distinct from (select f.completed_on from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f)
    )
    or (
      member_id = auth.uid()
      and profile_is_active(member_id)
      and certified = coalesce((select f.certified from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f), false)
      and completed_on is not distinct from (select f.completed_on from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 5. [CRITICAL] `loan_payments_insert_related`'s leader/staff branches let
--    either role directly INSERT a `loan_payments` row against ANY loan
--    (leader: any loan in her own SHG; staff: any loan platform-wide) with
--    none of `record_loan_payment()`'s (the app's only real, RPC-based
--    payment path, 0011/0073/0088/0098) safeguards: no self-exclusion (a
--    leader/staff who is also a borrowing member could pay off her own
--    loan), no overpayment check (amount can exceed `outstanding`), no
--    `loans.outstanding`/`status` update at all (the direct insert never
--    touches the loan row `record_loan_payment()` updates), producing a
--    forged row indistinguishable in Payment History from a real payment
--    while `sum(loan_payments.amount)` silently stops reconciling with
--    `loan.amount - loan.outstanding`. Grep confirms `LoanRepository.
--    recordPayment()` only ever calls the RPC — this policy has zero
--    legitimate call sites. `record_loan_payment()` is `security definer`
--    and performs its own internal insert, so it does not depend on this
--    policy at all. Retiring the policy entirely closes the forgery path
--    with no loss of legitimate functionality, matching the exact
--    precedent already used for `marketplace_orders_insert_staff` (0106)
--    and the member self-branch already retired from this same policy in
--    0108.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "loan_payments_insert_related" on public.loan_payments;

-- ─────────────────────────────────────────────────────────────────────────
-- 6. [MEDIUM] `AdminRepository.fetchTrainingCompletionPct()` fetched every
--    active-member id, every quizzed course_id, and the ENTIRE `course_
--    progress` table client-side just to sum one platform-wide percentage
--    — real at scale (this is the fastest-growing member × course
--    cross-product table in the schema) and, per round 196's own
--    documented reasoning, not fixable with a `.limit()` since capping the
--    underlying rows would silently make the computed percentage wrong
--    rather than merely show fewer rows. A proper server-side aggregate
--    was flagged as a follow-up in round 196 and again in this round's
--    Training audit — implementing it now: replicates the exact same
--    semantics (active-members-only denominator, certified-not-progress
--    for quizzed courses, progress for non-quizzed courses) as SQL
--    aggregates instead of a full-table client transfer.
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.training_completion_stats()
returns table (progress_sum bigint, total_members bigint, total_courses bigint)
language sql
security definer
stable
set search_path = public
as $$
  with active_members as (
    select id from public.profiles where role = 'member' and is_active = true
  ),
  quizzed_courses as (
    select distinct course_id from public.quiz_questions
  ),
  scored as (
    select
      case when qc.course_id is not null then (case when cp.certified then 100 else 0 end) else cp.progress end as points
    from public.course_progress cp
    join active_members am on am.id = cp.member_id
    left join quizzed_courses qc on qc.course_id = cp.course_id
  )
  select
    coalesce((select sum(points) from scored), 0)::bigint as progress_sum,
    (select count(*) from active_members)::bigint as total_members,
    (select count(*) from public.training_courses)::bigint as total_courses
  where public.is_staff();
$$;

revoke all on function public.training_completion_stats() from public, anon;
grant execute on function public.training_completion_stats() to authenticated;
