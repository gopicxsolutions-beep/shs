-- ─────────────────────────────────────────────────────────────────────────
-- scheme_applications_update_staff: block a staff account from deciding
-- her own application
--
-- Unlike every other decision-workflow table in this schema
-- (`loans_update_leader_or_staff` requires `loans_member_id(id) <>
-- auth.uid()`; `meeting_attendance`/`meeting_action_items` have their own
-- self-checks), `scheme_applications_update_staff`'s check was just
-- `is_staff()` — no exclusion of the applicant being the caller herself at
-- all. `scheme_applications_insert_self` has no role restriction (any
-- authenticated profile, including a crp/clf/admin account, can submit
-- `member_id = auth.uid()` for herself — the table has no `shg_id` column
-- to scope it further), and `scheme_applications_review_page.dart` (the
-- staff-only review queue) applies no client-side filter excluding the
-- reviewer's own application either. Concretely: a staff account who is
-- also a real SHG member could apply for a scheme, then approve or reject
-- her own application from the same review queue she uses for every other
-- member's — and, unlike the analogous loans/meetings gaps found in rounds
-- 92-93, this one wasn't merely a confusing UI in front of an RLS block:
-- the write would have genuinely succeeded. This is the same "no identity
-- may escalate itself" shape as every other decision workflow in this app;
-- it just hadn't been applied here yet.
--
-- Full live behavioral round-trip verification (self rejected, other-party
-- still allowed) was not performed for this specific fix — this live
-- project currently has exactly one real profile, with role 'leader', and
-- creating a new profile with a crp/clf/admin role to exercise the
-- is_staff() branch would cross into the same class of action already
-- blocked earlier this session (assigning a profile a staff/admin role).
-- The gap and the fix were instead verified deterministically by reading
-- the actual deployed policy expression before and after via
-- `pg_get_expr(polwithcheck, polrelid)` — the boolean condition itself is
-- unambiguous, not something that needs a live round-trip to confirm.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "scheme_applications_update_staff" on public.scheme_applications;

create policy "scheme_applications_update_staff" on public.scheme_applications
  for update using (is_staff() and member_id <> auth.uid())
  with check (is_staff() and member_id <> auth.uid());
