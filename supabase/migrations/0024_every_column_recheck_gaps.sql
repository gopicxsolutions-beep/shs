-- Systematic follow-up to round 46's adversarial re-verification (0023),
-- which found that both `loans_update_leader_or_staff` (0019) and
-- `marketplace_orders_update_seller_or_staff` (0018) had been "fixed" only
-- against the specific columns their own original bug report called out,
-- not against EVERY column the table actually has. This migration applies
-- that same full re-derivation — read every column in
-- `0001_init_schema.sql`, then check every remaining `for update`/`for all`
-- policy's `with check` names every one of them, explicitly deciding for
-- each unmentioned column whether it's genuinely fine for the actor to
-- freely change (e.g. `status` on a workflow row, `present` on
-- `meeting_attendance` — literally the point of that write) or a real gap —
-- to every other UPDATE-capable policy in the schema.
--
-- Full verdict (only the two fixed below were real, new, previously
-- undisclosed gaps; everything else re-derived clean):
--
--   shgs_update_leader_or_staff        -- NOT a new gap: 0013's own comment
--     already explicitly decided, in writing, to leave every column besides
--     `grade`/`clf`/`vo` open for the leader branch ("keep the leader able
--     to self-service the ordinary descriptive/operational fields (name,
--     address fields, bank details — a real future 'edit SHG profile'
--     feature this policy was clearly written to support)"). That is a
--     disclosed, deliberate design decision, not an oversight this task's
--     own instructions call for re-litigating unilaterally — flagged in the
--     session log for the team's own judgment, since `bank_account`/`ifsc`
--     self-service with no admin review is arguably worth a second look,
--     but not unilaterally changed here.
--   meeting_action_items_write_related -- NOT a new gap beyond what 0015
--     already explicitly disclosed-but-left-unfixed (the `owner_id`
--     cross-SHG-assignment gap). This pass's own new angle — the
--     `owner_id = auth.uid()` branch also never scopes `meeting_id` — is the
--     same shape as the `meeting_attendance` gap fixed below, but on a
--     table 0015 already reasoned is lower-stakes than attendance (nullable/
--     optional to-do assignment, no financial/attendance/audit-trail
--     weight, and the app doesn't even populate `owner_id` today) — left
--     disclosed-not-fixed, matching 0015's own precedent for this exact
--     table.
--   support_tickets_update_staff, scheme_applications (0012's staff-only
--     policy), financial_ledger_update_staff, payments_update_staff --
--     all fully staff-only (`using`/`with check` both just `is_staff()`),
--     so there is no non-admin/non-owner actor in the policy at all for a
--     column-lock gap to matter against. Safe.
--   course_progress_write_self_or_staff -- NOT a gap: `certified` is
--     self-set by `TrainingRepository.markCertified()` after the client-side
--     quiz "placeholder" (see `course_quiz_page.dart`'s own doc comment) by
--     original design, not an externally-assessed credential the schema
--     ever intended to gate behind staff review — self-certification IS the
--     feature. `course_id`/`member_id` are the upsert's own conflict key
--     (`onConflict: 'course_id,member_id'`), never independently
--     retargeted by the app, same low-stakes shape as the training-badge
--     display it feeds — not padded in.
--   shg_documents_write_leader_or_staff -- re-confirmed safe (0015's own
--     verdict): `shg_id` is the only identity column and it's already
--     scoped; `name`/`type`/`size`/`storage_path` are the actual point of a
--     leader managing her own SHG's document list.
--   meetings_write_leader_or_staff, livelihood_write_self_leader_or_staff,
--     marketplace_products_write_seller_or_staff, announcement_reads_self_
--     or_staff -- `created_at`/similar timestamp columns are technically
--     unlocked on all four, but each is a single-owner-scoped resource with
--     no adversarial second party whose interests a falsified timestamp
--     could damage (a leader's own SHG's own meeting/livelihood log, a
--     seller's own product listing, a member's own read-receipt) — distinct
--     from `announcements` below, whose `created_at` drives a
--     cross-membership shared feed's sort order that isn't the writer's
--     alone to see. Not fixed, to avoid padding low-stakes columns in.
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1. meeting_attendance_self_or_leader — the member's OWN self-check-in
--    branch never scopes `meeting_id` to her own SHG at all (unlike the
--    leader branch, which 0015 already scoped via `m.shg_id =
--    current_shg_id()`).
-- ─────────────────────────────────────────────────────────────────────────
-- `with check (member_id = auth.uid() or exists(...leader, scoped...) or
-- is_staff())` — the `member_id = auth.uid()` branch only ever verifies the
-- row is attributed to the caller herself; it does not verify `meeting_id`
-- belongs to a meeting in her own SHG, or to any meeting at all she has a
-- real relationship to. `MeetingRepository.markAttendance()` is called from
-- two places — the leader's roster (`meeting_attendance_page.dart`, already
-- covered by the leader branch) and the member's own self-check-in
-- (`meeting_qr_page.dart`), which always sources `meeting` from
-- `_repo.fetchForShg(shgId)` (the caller's own `shgId`) — so the app itself
-- never exercises anything but an own-SHG meeting here. But with no such
-- check in the policy, a direct `POST`/upsert to `meeting_attendance` with
-- `member_id = auth.uid()` and an arbitrary `meeting_id` from ANY OTHER
-- SHG's meeting succeeds today — a member could fabricate her own
-- "present" attendance at a meeting she was never part of (or take her own
-- existing attendance row and retarget its `meeting_id`, since `upsert`'s
-- conflict key is `(meeting_id, member_id)` and nothing freezes the column
-- once written), polluting that other SHG's attendance report/analytics
-- and her own attendance-rate figures. Fix: require the target meeting
-- belong to the caller's own SHG in the self-branch too, mirroring the
-- scope the leader branch already enforces — no self-referencing subquery
-- involved (this joins to the separate `meetings` table, not back to
-- `meeting_attendance` itself), so this doesn't carry the 0018/0019
-- recursion risk.

drop policy if exists "meeting_attendance_self_or_leader" on public.meeting_attendance;

create policy "meeting_attendance_self_or_leader" on public.meeting_attendance
  for all using (
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

-- ─────────────────────────────────────────────────────────────────────────
-- 2. announcements_write_leader_or_staff — `created_at` was never locked,
--    unlike `created_by` (0015).
-- ─────────────────────────────────────────────────────────────────────────
-- Full column list (0001_init_schema.sql): id, shg_id, title, body,
-- category, created_by, created_at. 0015 correctly locked `created_by` to
-- `auth.uid()` (closing the misattribution gap) but the policy still never
-- references `created_at`. `AnnouncementRepository` only ever calls
-- `.insert()` (grepped — no `.update()`/`.delete()` call site exists), so
-- the FOR ALL policy's UPDATE path is unused-by-the-app REST-only surface,
-- same as several prior fixes — but `AnnouncementRepository.fetchFor(...)`
-- orders the whole shared feed by `created_at` descending, and this is a
-- genuinely cross-membership, shared, staff/every-SHG-member-visible feed
-- (unlike `meetings`/`livelihood_activities`, which are single-owner-scoped
-- with no other party's interests at stake) — a leader could directly PATCH
-- her own SHG's already-posted announcement's `created_at` to push a
-- circular to the top of everyone's feed long after the fact, or bury an
-- inconvenient one under newer posts, exactly the same "falsify the
-- record's own timestamp to manipulate ordering/reporting" class of bug
-- 0023 just fixed for `marketplace_orders.created_at`. Fix: same
-- security-definer read-gated locked-fields pattern already established
-- (avoids the 0018/0019 self-referencing-subquery recursion), gated to the
-- exact same visibility `announcements_select_scope_or_staff` already
-- allows (global, own SHG, or staff) so this isn't a fresh unrestricted
-- read surface.
--
-- One more wrinkle the original 0018/0019 pattern didn't have to deal with:
-- `announcements_write_leader_or_staff` is a single `for all` policy
-- (covers INSERT too), but a locked-field lookup keyed on the row's own id
-- returns NO ROWS for a brand-new INSERT (the row doesn't exist yet when
-- the function runs), which would make `created_at = (select ... )`
-- evaluate to `created_at = NULL` — always false — and silently break EVERY
-- legitimate new announcement, not just the attack path. `loans`/
-- `marketplace_orders` never hit this because their locked-field policies
-- are `for update` only. Fix: split this policy into separate INSERT and
-- UPDATE(+DELETE) policies, matching the precedent 0014 already established
-- for `financial_ledger` (same "insert has different rules than
-- update/delete" shape) — INSERT keeps the existing scope/`created_by`
-- check with no `created_at` lock (there's nothing to lock yet), and only
-- the new UPDATE policy adds the `created_at` freeze.

create or replace function public.announcements_created_at(p_id uuid)
returns table (created_at timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select a.created_at
  from public.announcements a
  where a.id = p_id
    and (a.shg_id is null or a.shg_id = public.current_shg_id() or public.is_staff());
$$;

revoke all on function public.announcements_created_at(uuid) from public;
grant execute on function public.announcements_created_at(uuid) to authenticated;

drop policy if exists "announcements_write_leader_or_staff" on public.announcements;

create policy "announcements_insert_leader_or_staff" on public.announcements
  for insert with check (
    (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
    )
    and created_by = auth.uid()
  );

create policy "announcements_update_leader_or_staff" on public.announcements
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
    )
    and created_by = auth.uid()
    and created_at = (select f.created_at from public.announcements_created_at(announcements.id) f)
  );

create policy "announcements_delete_leader_or_staff" on public.announcements
  for delete using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  );
