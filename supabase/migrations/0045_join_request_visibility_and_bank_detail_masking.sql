-- Two real gaps found by a fresh adversarial audit of the "My SHG" module
-- (shg_home_page.dart, shg_members_page.dart, shg_documents_page.dart,
-- shg_join_requests_page.dart, member_detail_page.dart) prompted by a user
-- report that the module "looks incomplete."
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1. A leader could never actually see WHO was requesting to join her SHG
-- ─────────────────────────────────────────────────────────────────────────
--
-- `ShgJoinRequestRepository.fetchPendingForShg()`
-- (lib/repositories/shg_join_request_repository.dart) embeds `profiles(name)`
-- alongside every pending `shg_join_requests` row, and
-- `shg_join_requests_page.dart` falls back to a generic "Member" label
-- (`shgJoinRequestsMemberFallback`) whenever that embed comes back null --
-- clearly meant as a rare defensive fallback, not the *only* thing a leader
-- would ever see.
--
-- But it WAS the only thing a leader would ever see, for every single
-- request, with no exception: `ShgJoinRequestRepository.submit()`
-- (0004_shg_join_requests.sql's own table) inserts only into
-- `shg_join_requests` -- it deliberately never touches `profiles.shg_id`
-- (see AppState.completeProfileSetup's own doc comment: "shgId is
-- deliberately NOT passed here -- membership only takes effect once the
-- SHG's leader approves the join request"). So a pending requester's
-- `profiles.shg_id` is *always* null until approved.
--
-- `profiles_select_self_shg_or_staff` (0002_rls_policies.sql) reads:
--   id = auth.uid() or shg_id = current_shg_id() or is_staff()
-- A leader is not staff, and `null = current_shg_id()` is never true in SQL
-- regardless of what `current_shg_id()` returns -- so this policy can
-- *never* grant a leader visibility into a pending requester's profile row.
-- PostgREST silently returns `null` for an embedded relation RLS denies
-- (not an error), so the bug was invisible in casual testing: the page
-- never crashed, it just permanently showed "Member" for every single
-- request instead of a real name, with no error to notice. Confirmed via
-- direct read of the insert path and the policy text (no live join-request
-- rows existed in this project to reproduce against directly, but the SQL
-- semantics are unconditional: NULL never equals anything, including via
-- `=`).
--
-- Fixed by extending the policy with an additional clause: a leader can see
-- the profile of any member with a currently-PENDING request to her own
-- SHG. Deliberately scoped to `status = 'pending'` only -- once a request
-- is approved, the member's `shg_id` naturally starts matching the existing
-- `shg_id = current_shg_id()` clause instead; once rejected, they should
-- become invisible to that leader again, matching the intended lifecycle.
-- The `shg_join_requests` row itself is already leader-readable for the
-- leader's own SHG (`shg_join_requests_select_self_leader_or_staff`,
-- 0004), so this EXISTS check doesn't newly expose anything about the
-- join-request table itself -- only extends the *profile* the leader can
-- already partially see (via the request row) to include enough of that
-- member's own profile to make an informed approve/reject decision.
create policy "profiles_select_pending_join_requester" on public.profiles
  for select using (
    exists (
      select 1 from public.shg_join_requests r
      where r.member_id = profiles.id
        and r.shg_id = public.current_shg_id()
        and r.status = 'pending'
    )
  );

-- Note: this is an ADDITIONAL policy, not a replacement for
-- `profiles_select_self_shg_or_staff` -- Postgres RLS policies for the same
-- command are OR'd together, so this purely adds visibility, never removes
-- it. `lib/repositories/shg_join_request_repository.dart`'s
-- `fetchPendingForShg()` embed now correctly resolves `profiles(name,
-- mobile)` for a real requester instead of silently returning null (the
-- Dart-side model/UI change to also surface `mobile` -- so a leader can
-- distinguish two same-named requesters or sanity-check identity before
-- approving -- ships in the same app change as this migration).

-- ─────────────────────────────────────────────────────────────────────────
-- 2. shgs.bank_account/ifsc were readable by every ordinary member, not
--    just the leader/staff who actually need them
-- ─────────────────────────────────────────────────────────────────────────
--
-- `shgs_select_own_or_staff` (0002_rls_policies.sql) is a plain row-level
-- policy -- `id = current_shg_id() or is_staff()` -- with no column
-- distinction, so a `select *` (exactly what `ShgRepository.fetchShg()`
-- issues, lib/repositories/shg_repository.dart) returns bank_account/ifsc
-- to any member of the SHG, not just its leader. `shg_home_page.dart` only
-- *renders* the "Bank Details" section `if (isLeaderOrStaff)` -- a
-- client-side check, and per this project's own standing rule ("RLS in
-- Postgres is authorization. Client-side role checks are UX only.") that
-- was never actually closing the gap: any member's client can already see
-- her own SHG's bank_account/ifsc in the raw API response regardless of
-- what the UI chooses to paint. This directly contradicts this project's
-- own stated model for these two columns specifically ("shgs.bank_account/
-- ifsc are sensitive -- never expose through a broadly-readable view").
--
-- Postgres RLS is row-level, not column-level, and column-level GRANTs
-- can't be conditioned on the querying role dynamically (every authenticated
-- user shares the single `authenticated` Postgres role) -- so, matching the
-- `shg_directory` view's own established pattern for "safe subset of a
-- sensitive table," a second view does the masking: same row-visibility
-- rule as the base table's own policy (own SHG or staff), but
-- bank_account/ifsc are nulled out unless the caller is leader/staff for
-- that SHG.
create or replace view public.shg_own_masked
with (security_invoker = false) as
  select
    id, name, reg_number, formation_date, village, mandal, district, state,
    bank_name, grade, clf, vo,
    case when public.is_leader_or_staff() then bank_account else null end as bank_account,
    case when public.is_leader_or_staff() then ifsc else null end as ifsc
  from public.shgs
  where id = public.current_shg_id() or public.is_staff();

grant select on public.shg_own_masked to authenticated;

-- `ShgRepository.fetchShg()` (the single-row "my own SHG" lookup used by
-- shg_home_page.dart, scheme eligibility, etc.) now selects from this view
-- instead of the base `shgs` table in live mode -- ships in the same app
-- change as this migration. `ShgRepository.fetchAllShgs()` (admin-only
-- Manage SHGs listing, gated by `is_staff()` at the RLS row level already)
-- deliberately keeps reading the base table directly: an admin legitimately
-- needs the real, unmasked bank_account/ifsc for financial oversight, and
-- `is_leader_or_staff()` already evaluates true for any staff caller, so
-- the view would have returned the same unmasked values to them anyway --
-- reading the base table there is just more direct, not a gap.
