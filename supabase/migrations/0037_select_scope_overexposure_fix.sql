-- Fresh, adversarial re-derivation of every `for select using` policy in the
-- schema (rounds 46-50 covered UPDATE/DELETE/INSERT/SELECT already, and
-- round 50's own SELECT pass, plus round 13's earlier per-table verdict
-- list, both judged `scheme_applications_select_related` and
-- `course_progress_select_related` "Safe... consistent with the documented
-- same-SHG transparency model as savings/loans" — but neither pass actually
-- cross-checked that reasoning against the app's real call sites, which is
-- exactly what this round did, and it doesn't hold up for either table).
--
-- ─────────────────────────────────────────────────────────────────────────
-- Why savings/loans/meetings/financial_ledger/livelihood_activities are
-- correctly LEFT ALONE (re-derived, not just re-asserted, before concluding
-- these two are different):
-- ─────────────────────────────────────────────────────────────────────────
-- 0002_rls_policies.sql's own header comment names the intentionally shared
-- family: "share read access to operational data (savings, loans, meetings,
-- ledger)" — CLAUDE.md repeats the same four by name. `livelihood_activities`
-- isn't literally named either, but it shares that family's structural
-- signature: it stores its own `shg_id` column directly, compares it to
-- `current_shg_id()` the same way the other four do, and
-- `livelihood_home_page.dart`'s leader/staff branch really does fold
-- SHG-wide `fetchForShg()` rows into a shared per-SHG total — a genuine,
-- deliberately-provisioned transparency feature even though (like loans) the
-- plain-member branch of the UI currently only calls `fetchForMember`.
--
-- `scheme_applications` and `course_progress` are structurally different:
-- neither table even HAS a `shg_id` column (see 0001_init_schema.sql — both
-- are keyed only by `member_id`), which is why their SELECT policies had to
-- reach for the `profile_shg_id(member_id)` indirection (looking up the
-- APPLICANT's own `shg_id` via a security-definer helper) instead of the
-- direct `shg_id = current_shg_id()` comparison every other shared table
-- uses. That's a meaningfully more contrived construction, and grepping
-- every real call site confirms it was never actually exercised by anything:
--   * `SchemeRepository.fetchMyApplications()` — always
--     `.eq('member_id', memberId)`, own rows only (scheme_tracking_page.dart,
--     schemes_home_page.dart).
--   * `SchemeRepository.fetchPendingApplications()` — the one genuinely
--     SHG-agnostic, multi-row read in the file, and it's deliberately
--     unfiltered by SHG (FR-SCH-4: staff review "a shared PLATFORM-WIDE
--     queue", not an SHG-scoped one) and reached only from
--     `SchemeApplicationsReviewPage`, whose own doc comment reads
--     "Staff-only review queue" — already fully covered by the policy's
--     separate `is_staff()` branch, independent of `profile_shg_id()`.
--   * `TrainingRepository.fetchMyProgress()` — same shape, always
--     `.eq('member_id', memberId)` (certificates_page.dart,
--     course_detail_page.dart, training_home_page.dart,
--     member_dashboard.dart).
--   * No leader/CRP/CLF/admin dashboard (leader_dashboard.dart,
--     crp_dashboard.dart, clf_dashboard.dart, admin_dashboard.dart) calls
--     either repository with anything but the caller's own id, or (for
--     staff) the already-`is_staff()`-gated review queue.
-- docs/SRS.md's own feature spec matches this: FR-SCH-3 frames scheme
-- applications as "self-service only" tracking of the member's OWN status;
-- FR-TRN-5 frames training visibility for staff as "aggregate level" only.
-- Neither describes a fellow-SHG-member peer-visibility feature, unlike
-- FR-SAV-3's explicit "SHG members share realtime read access to the
-- group's savings ledger".
--
-- ─────────────────────────────────────────────────────────────────────────
-- The real gap: concrete exploit
-- ─────────────────────────────────────────────────────────────────────────
-- With the un-exercised `profile_shg_id(member_id) = current_shg_id()`
-- branch live, any ordinary member — no special role needed — can bypass
-- the app's own UI entirely and, with her own JWT, call:
--   GET /rest/v1/scheme_applications?select=*,schemes(name),profiles(name)
--   GET /rest/v1/course_progress?select=*,training_courses(title)
-- and receive EVERY fellow SHG member's row: which government scheme each
-- named member has applied for and whether it's still `applied`/
-- `under_review` (i.e. not yet decided by staff) or already
-- `approved`/`rejected`; and every fellow member's exact training quiz
-- progress percentage and certification status per course. No app UI, for
-- any role, ever shows a plain member this — it's a pure direct-REST-only
-- exposure, exactly the "direct REST exposes more than the UI shows" gap
-- this session has repeatedly found and closed on the WRITE side
-- (0013/0034/0035/0036); this is the same shape on the READ side.
--
-- Fix: drop the unused `profile_shg_id()` branch from both policies,
-- leaving exactly `member_id = auth.uid() or is_staff()` — matches the
-- `payments_select_self_or_staff` precedent (0013) for the identical
-- "individual record, not a shared SHG ledger entry" reasoning. Costs zero
-- real functionality: every verified call site above already stays within
-- this narrower scope.
--
-- ─────────────────────────────────────────────────────────────────────────
-- Migration-numbering note: 0036 was the highest migration on disk when
-- this file was written. This session's rounds have repeatedly run multiple
-- agents in parallel each auditing a different bug class in the same round
-- (round 82's own log records exactly this collision for 0035/0036) — a
-- sibling agent auditing INSERT policies this same round may independently
-- also claim `0037`. Check `supabase/migrations/` for a real collision
-- before deploying either file, and renumber whichever one loses, same as
-- round 82 did.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "scheme_applications_select_related" on public.scheme_applications;

create policy "scheme_applications_select_related" on public.scheme_applications
  for select using (
    member_id = auth.uid() or public.is_staff()
  );

drop policy if exists "course_progress_select_related" on public.course_progress;

create policy "course_progress_select_related" on public.course_progress
  for select using (
    member_id = auth.uid() or public.is_staff()
  );
