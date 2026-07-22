-- Found during a dedicated SQL-correctness audit pass (round 11 of this
-- session): `scheme_applications_update_self_or_staff` (0002_rls_policies.sql)
-- is:
--
--   for update using (member_id = auth.uid() or public.is_staff());
--
-- with no `with check` — so it defaults to the same permissive USING
-- clause. That means any member can update EVERY column, including
-- `status`, on their OWN scheme_applications row — not just insert/withdraw
-- it. `status` is the government-scheme approval decision itself
-- ('applied' → 'under_review' → 'approved'/'rejected'), meant to be a
-- staff-only call (see `lib/repositories/scheme_repository.dart`'s
-- `decideApplication()`, only ever reachable from the staff-only
-- `SchemeApplicationsReviewPage` per its own doc comment: "Only staff
-- (crp/clf/admin) can reach this per `is_staff()`, matching the RLS's own
-- staff-only write scope"). That comment describes the INTENDED design,
-- but the actual RLS policy does not match it: nothing server-side stops a
-- member from calling
-- `PATCH /rest/v1/scheme_applications?id=eq.<their-own-application>` with
-- `{"status":"approved"}` directly and self-approving their own government
-- scheme application, completely bypassing staff review — the same bug
-- shape (self-service write to a field that's supposed to require a
-- higher-privilege actor) as the profiles role-escalation bug fixed in
-- 0009_profiles_role_escalation_fix.sql, just on `scheme_applications`
-- instead of `profiles`. No app UI exercises the member-self-update path
-- today (members only ever INSERT via `apply()` — see
-- `scheme_applications_insert_self`), so restricting this policy to
-- staff-only closes the gap with no loss of any real, currently-used
-- feature.
--
-- Fix: replace the policy with a staff-only one, matching what the
-- application code has always assumed this policy already enforced.

drop policy if exists "scheme_applications_update_self_or_staff" on public.scheme_applications;

create policy "scheme_applications_update_staff" on public.scheme_applications
  for update using (public.is_staff()) with check (public.is_staff());
