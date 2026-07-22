-- Full scheme-application-lifecycle audit (this session had previously only
-- verified the eligibility-matching heuristic in schemes_home_page's earlier
-- round, never the surrounding apply/withdraw/deadline flow). One genuine,
-- concrete gap found: `schemes.deadline` is stored, displayed on the scheme
-- detail card, and even used to order the catalog ('order(deadline)' in
-- SchemeRepository.fetchSchemes) — but nothing, client or server, ever
-- checked it before accepting an application. A member could tap "Apply Now"
-- on a scheme whose deadline had already passed and the insert would
-- silently succeed, with the staff review queue then showing an application
-- for an already-closed scheme with no indication it was submitted late.
-- (Concretely reproducible with this app's own seed data: PMEGP and MUDRA in
-- lib/data/schemes.dart carry deadlines of 15 Jul 2026 / 10 Jul 2026, both
-- already in the past as of this audit.)
--
-- The paired Dart-side fix (lib/pages/schemes/scheme_detail_page.dart) now
-- hides the "Apply Now" button once `scheme.deadline` is in the past, but
-- that alone is only a UI nicety — nothing stopped a direct
-- `POST /rest/v1/scheme_applications` call (or a future code path) from
-- inserting an application for an expired scheme. This migration closes it
-- at the RLS layer, the same "server is the actual source of truth"
-- pattern as every other insert/update lockdown in this schema (0009, 0012,
-- 0022, 0027, ...).
--
-- Other application applications (duplicate-application prevention,
-- withdrawal, and post-decision audit visibility) were also checked in the
-- same pass and found already correct/intentional, not touched here:
--   - Duplicate applications: `unique (scheme_id, member_id)` (0001) already
--     makes a second row for the same member+scheme impossible at the DB
--     level; a raced double-submit fails on the unique-violation and the
--     existing generic error handling in `SchemeDetailPage._apply` covers
--     it without misleading the user.
--   - Withdrawal: `scheme_applications` has no delete policy at all, and
--     0026's dedicated delete-policy audit pass already re-confirmed this
--     as an intentional, correct design (an application is an audit-trail
--     record once submitted, the same treatment as loan_payments/
--     support_tickets/support_messages) — not revisited here.
--   - Post-decision visibility: `decide_scheme_application` (0029) already
--     raises when a second staff account races a stale queue view, and
--     `SchemeApplicationsReviewPage._decide`'s
--     `on SchemeApplicationAlreadyDecidedException` branch already reloads
--     the queue and surfaces "This application was already decided by
--     someone else." — the stale-view-until-refresh window inherent to a
--     non-realtime list is a pre-existing, app-wide `AppAsyncBuilder`
--     pattern (every list screen in this app works this way), not a
--     scheme-application-specific bug.

drop policy if exists "scheme_applications_insert_self" on public.scheme_applications;

create policy "scheme_applications_insert_self" on public.scheme_applications
  for insert with check (
    member_id = auth.uid()
    and status = 'applied'
    and applied_on = current_date
    and exists (
      select 1 from public.schemes s
      where s.id = scheme_id
        and (s.deadline is null or s.deadline >= current_date)
    )
  );
