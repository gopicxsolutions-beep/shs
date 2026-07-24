-- Rounds 11-13 exhaustively re-checked every RLS `update`/`all`/`delete`
-- policy for missing/buggy `using`/`with check` clauses (9 confirmed bugs
-- fixed across 0009/0012/0013/0014). This migration applies the exact same
-- methodology to the one remaining unexamined surface: every `for insert`
-- (and the INSERT half of every `for all`) policy in the schema. The
-- specific shape hunted for here is narrower than the UPDATE-side bugs:
-- those had `with check` missing entirely; every INSERT policy in this
-- schema already HAS a `with check` clause, but several of them check the
-- wrong thing — they verify the actor's ROLE and SHG scope, but never
-- verify that the ROW's own identity-bearing column (`member_id`,
-- `created_by`, `buyer_id`) is actually consistent with that scope. That
-- gap lets an actor who is legitimately allowed to insert *something*
-- insert a row that impersonates or misattributes a *different* person.
--
-- Full table-by-table verdict for every `for insert`/`for all` policy in
-- 0002/0004/0006/0009/0012/0013/0014 (29 policies with an INSERT path):
--
--   profiles_insert_self                        -- safe (id = auth.uid())
--   shgs_insert_staff                            -- safe (staff-only, no member-identity column on shgs)
--   shg_documents_write_leader_or_staff          -- safe (shg_id is the only identity column, already scoped)
--   savings_insert_self_leader_or_staff          -- BUGGY, fixed below (#1)
--   loans_insert_self                            -- safe (member_id = auth.uid() AND shg_id = current_shg_id())
--   loan_payments_insert_related                 -- safe (bound via the referenced loan's own member_id/shg_id, not a free column)
--   meetings_write_leader_or_staff                -- safe (shg_id is the only identity column, already scoped)
--   meeting_attendance_self_or_leader            -- BUGGY, fixed below (#2)
--   meeting_minutes_write_leader_or_staff        -- safe (no member-identity column at all)
--   meeting_action_items_write_related           -- gap disclosed, NOT fixed (see note below)
--   financial_ledger_insert_leader_or_staff      -- BUGGY, fixed below (#3) (policy name from 0014's split of the old `_write_` policy)
--   livelihood_write_self_leader_or_staff        -- BUGGY, fixed below (#4)
--   marketplace_products_write_seller_or_staff   -- safe (seller_id = auth.uid() or staff)
--   marketplace_orders_insert_authenticated      -- BUGGY, fixed below (#5)
--   marketplace_reviews_insert_authenticated     -- safe-by-structure, see note below (no identity column exists on the table to bind)
--   schemes_write_admin                          -- safe (admin-only)
--   scheme_applications_insert_self              -- verified correct: member_id = auth.uid(), nothing more needed
--   training_courses_write_staff                 -- safe (staff-only)
--   course_progress_write_self_or_staff          -- safe (member_id = auth.uid() or staff)
--   payments_insert_self_or_staff                -- verified correct (0013's INSERT half): member_id = auth.uid() or staff
--   announcements_write_leader_or_staff          -- BUGGY, fixed below (#6)
--   announcement_reads_self_or_staff             -- safe (member_id = auth.uid() or staff)
--   support_tickets_insert_self                  -- safe (member_id = auth.uid())
--   support_messages_insert_related              -- safe (sender_id = auth.uid() AND ticket-membership check)
--   ai_advisor_logs_insert_self                  -- safe (member_id = auth.uid())
--   report_snapshots_write_staff                 -- safe (staff-only)
--   analytics_kpis_write_staff                   -- safe (staff-only)
--   audit_log_insert_self                        -- safe (actor_id = auth.uid())
--   shg_join_requests_insert_self                -- safe (member_id = auth.uid())
--
-- Every `is_staff()`-only branch above is intentionally left as-is: this
-- schema consistently treats crp/clf/admin as fully trusted actors for
-- writes across every table (see 0002's own top-of-file design comment),
-- so an unconstrained staff branch is the schema's deliberate trust model,
-- not a fresh instance of this bug class — matches how 0013/0014 also never
-- touched a staff-only branch.
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1. savings_insert_self_leader_or_staff — a leader could record a savings
--    deposit against a member who ISN'T actually in her SHG.
-- ─────────────────────────────────────────────────────────────────────────
-- `for insert with check (member_id = auth.uid() or (shg_id =
-- current_shg_id() and current_role() = 'leader') or is_staff())`. The
-- leader branch verifies `shg_id = current_shg_id()` (she can only post
-- into her OWN group's book) and `current_role() = 'leader'`, but never
-- verifies that `member_id` — the person the deposit is actually credited
-- to — is a member of that SHG at all. `savings_entry_page.dart`'s leader
-- flow populates the member picker from `ShgRepository.fetchMembers
-- (appState.profile?.shgId)`, i.e. only ever offers members of her own
-- group, so the app UI never exercises this gap — but nothing server-side
-- stops a direct `POST /rest/v1/savings_entries` with `shg_id` set to her
-- own SHG and `member_id` set to a completely unrelated person's profile
-- id (a member of a different SHG, or even a staff account) — fabricating
-- a deposit record that shows up in THAT stranger's own savings history
-- (`savings_select_shg_or_staff` lets `member_id = auth.uid()` read it)
-- while being booked against a group they never joined. Fix: reuse the
-- `profile_shg_id()` helper this schema already trusts for exactly this
-- kind of cross-table membership check (see `scheme_applications_select_
-- related`/`course_progress_select_related`) to require the credited
-- member's own `shg_id` to match the SHG the leader is posting into.
drop policy if exists "savings_insert_self_leader_or_staff" on public.savings_entries;

create policy "savings_insert_self_leader_or_staff" on public.savings_entries
  for insert with check (
    member_id = auth.uid()
    or (
      shg_id = public.current_shg_id()
      and public.current_role() = 'leader'
      and public.profile_shg_id(member_id) = shg_id
    )
    or public.is_staff()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. meeting_attendance_self_or_leader — a leader could mark "attendance"
--    for a person who isn't in her SHG at all, at one of her meetings.
-- ─────────────────────────────────────────────────────────────────────────
-- Identical shape to #1: the leader branch of `with check` confirms the
-- MEETING belongs to her own SHG (`m.shg_id = current_shg_id()`) and that
-- she's a leader, but never confirms `meeting_attendance.member_id` is
-- actually a member of that same SHG. `MeetingRepository.markAttendance()`
-- always sources `memberId` from `fetchRoster(shgId)` (the meeting's own
-- SHG roster), so the app never exercises this — but a direct `POST`/
-- upsert to `meeting_attendance` with a real `meeting_id` from her own SHG
-- and an arbitrary `member_id` from anywhere else would succeed today,
-- fabricating an attendance record (feeding into
-- `attendance_report_page.dart` and analytics) for someone who was never
-- actually part of that meeting or group. Fix: same `profile_shg_id()`
-- cross-check as #1, added inside the leader `exists` branch.
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
    member_id = auth.uid()
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
-- 3. financial_ledger_insert_leader_or_staff — a leader could post a
--    cashbook/ledger row and attribute it (`created_by`) to a DIFFERENT
--    person entirely, corrupting the audit trail this column exists for.
-- ─────────────────────────────────────────────────────────────────────────
-- (Policy name/split is from 0014, which separated the old single `for all`
-- `financial_ledger_write_leader_or_staff` into insert/update/delete —
-- 0014 fixed the UPDATE/DELETE halves' scope but the INSERT half it kept
-- still has this pre-existing gap.) `with check ((shg_id = current_shg_id()
-- and current_role() = 'leader') or is_staff())` never touches
-- `created_by` at all — 0006 made the column NOT NULL specifically because
-- "financial_ledger is the audit ledger itself, so a row with no actor
-- attached defeats its purpose", but nothing stops the actor from
-- attaching a REAL, but WRONG, actor. `FinancialRepository.addEntry()`
-- always passes `createdBy: appState.profile?.id` (the caller's own id,
-- both through `add_financial_ledger_entry` — `security invoker`, so this
-- RLS check is the RPC's actual boundary too — and its direct-insert
-- fallback), so the app itself never misattributes an entry — but a leader
-- calling either the RPC or the raw REST endpoint directly could set
-- `created_by` to any other profile id (e.g. a co-leader, or staff), making
-- it look like someone else posted a ledger entry they never touched —
-- useful for shifting blame for a disputed cashbook figure onto an
-- innocent party. Fix: require `created_by = auth.uid()`, i.e. the ledger
-- can only ever record who ACTUALLY made the call, matching what the app
-- has always done in practice.
drop policy if exists "financial_ledger_insert_leader_or_staff" on public.financial_ledger;

create policy "financial_ledger_insert_leader_or_staff" on public.financial_ledger
  for insert with check (
    (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
    )
    and created_by = auth.uid()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 4. livelihood_write_self_leader_or_staff — a leader could log a
--    livelihood activity against a member who isn't in her SHG.
-- ─────────────────────────────────────────────────────────────────────────
-- Identical shape to #1/#2. `with check (member_id = auth.uid() or (shg_id
-- = current_shg_id() and current_role() = 'leader') or is_staff())` never
-- verifies `member_id` actually belongs to `shg_id`. `LivelihoodRepository.
-- addActivity()` is only ever called with a `memberId` the UI sourced from
-- the caller's own SHG roster, so unused by the app — but a direct REST
-- call could fabricate an "investment"/"revenue" activity record credited
-- to (or blamed on) a member of a completely different group, which would
-- then surface in THAT person's own livelihood history and any
-- staff-facing analytics keyed off it. Fix: same `profile_shg_id()`
-- cross-check.
drop policy if exists "livelihood_write_self_leader_or_staff" on public.livelihood_activities;

create policy "livelihood_write_self_leader_or_staff" on public.livelihood_activities
  for all using (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  ) with check (
    member_id = auth.uid()
    or (
      shg_id = public.current_shg_id()
      and public.current_role() = 'leader'
      and public.profile_shg_id(member_id) = shg_id
    )
    or public.is_staff()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 5. marketplace_orders_insert_authenticated — ANY authenticated member
--    could place an order and attribute it to a COMPLETELY DIFFERENT
--    buyer, impersonating them in the seller's order queue.
-- ─────────────────────────────────────────────────────────────────────────
-- `for insert with check (auth.role() = 'authenticated')` — the loosest
-- policy in the whole schema: it doesn't check anything about the ROW at
-- all, not even the `buyer_id` column 0002 itself added specifically "to
-- make per-buyer RLS possible" (see 0002's own top-of-file comment on this
-- table). `MarketplaceRepository.placeOrder()` always sends `'buyer_id':
-- appState.profile?.id` (the caller's own id) — the app never misuses this
-- — but nothing server-side stops a direct `POST /rest/v1/marketplace_
-- orders` with `buyer_id` set to any other real member's id and
-- `buyer_name` set to their real name, creating a phantom order that shows
-- up as a genuine purchase in that other person's order history AND in the
-- seller's queue (`marketplace_orders_select_related` lets `buyer_id =
-- auth.uid()` read it) — a real impersonation vector: framing someone else
-- for an order they never placed, or (combined with `amount` already being
-- server-trusted via `decrement_product_stock` since 0008) at minimum
-- polluting another member's purchase history and a seller's fulfillment
-- queue with fabricated orders under a stranger's name. Fix: require
-- `buyer_id` to either be null (matches the column's original nullable
-- design for any caller who genuinely has no linked buyer profile) or
-- exactly the caller's own id — never someone else's.
drop policy if exists "marketplace_orders_insert_authenticated" on public.marketplace_orders;

create policy "marketplace_orders_insert_authenticated" on public.marketplace_orders
  for insert with check (
    auth.role() = 'authenticated'
    and (buyer_id is null or buyer_id = auth.uid())
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 6. announcements_write_leader_or_staff — a leader could post an
--    announcement and attribute authorship (`created_by`) to someone else.
-- ─────────────────────────────────────────────────────────────────────────
-- Same shape as #3: `with check ((shg_id = current_shg_id() and
-- current_role() = 'leader') or is_staff())` never touches `created_by`.
-- `AnnouncementRepository.post()` always passes the caller's own profile id
-- (`announcements_home_page.dart` calls `_repo.post(..., createdBy:
-- memberId, ...)` with the signed-in member's own id) — unused by the app
-- — but a direct REST call could post an announcement to the leader's own
-- SHG while setting `created_by` to a different leader, staff member, or
-- any other profile id, misattributing who actually issued a circular/
-- meeting notice/training/scheme announcement the whole group sees. Fix:
-- require `created_by = auth.uid()`, matching #3's fix and rationale
-- exactly.
drop policy if exists "announcements_write_leader_or_staff" on public.announcements;

create policy "announcements_write_leader_or_staff" on public.announcements
  for all using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  ) with check (
    (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
    )
    and created_by = auth.uid()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Explicitly disclosed, NOT fixed (judgment calls, matching round 12's
-- precedent of disclosing-but-not-unilaterally-fixing lower-stakes gaps):
--
-- * meeting_action_items_write_related — the leader branch of `with check`
--   has the identical missing-membership-check shape as #1/#2/#4 for
--   `owner_id` (a leader could assign an action item to someone outside
--   her SHG). Judged materially lower-stakes than the fixed cases: it's a
--   to-do-list assignment, not a financial record or attendance/audit
--   trail, `owner_id` is nullable and optional, and — unlike the other
--   four — the app's own `addActionItem()` call doesn't even pass an
--   `ownerId` today (`meeting_mom_page.dart`'s `_addActionItem()` never
--   supplies one), so there's no real "impersonation" scenario being
--   closed, only a hypothetical direct-REST misassignment of a task with
--   no financial or reputational stakes attached.
--
-- * marketplace_reviews_insert_authenticated — structurally can't have this
--   bug: unlike `marketplace_orders` (which got a real `buyer_id` FK column
--   added in 0002 specifically to make ownership enforceable), `marketplace_
--   reviews` still only has a free-text `reviewer_name` column with no FK
--   back to `profiles` at all — there is no identity-bearing column for a
--   `with check` to bind in the first place. This is the same pre-existing
--   "review/order authorship is just a free-text label" design gap round 11
--   already flagged for `buyer_name` before 0002 added `buyer_id` — closing
--   it for reviews would mean adding a new `reviewer_id` column (a schema
--   change, not an RLS policy fix), which is out of scope for this
--   with-check-focused migration; flagged here for the team's own
--   prioritization rather than silently left unmentioned.
-- ─────────────────────────────────────────────────────────────────────────
