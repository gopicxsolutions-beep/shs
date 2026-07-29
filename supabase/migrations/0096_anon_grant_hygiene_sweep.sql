-- Gap-hunt round 189 (iteration 17): systemic follow-up to 0095's hotfix.
-- That migration fixed one confirmed-exploitable case; this sweep closes
-- the same "revoke from public isn't enough" gap (0055's originally-
-- diagnosed root cause) everywhere else it silently reappeared.
--
-- Root cause, confirmed live via pg_proc.proacl: this project's `public`
-- schema has a default-privilege grant handing EXECUTE on every newly
-- created function to `anon`/`authenticated`/`service_role` automatically,
-- independent of the `PUBLIC` pseudo-role. Every migration since 0004 that
-- wrote the older `revoke all ... from public; grant execute ... to
-- authenticated;` idiom (rather than 0055's `revoke execute ... from anon,
-- authenticated`) left its function's own `anon` grant untouched. A live
-- sweep of every SECURITY DEFINER function in `public` found 24 more
-- instances of this beyond the two 0095 already fixed.
--
-- Impact assessment (verified by reading each function's own body, not
-- assumed): every one of these already gates its real logic on
-- `auth.uid()`-derived state (`current_role()`, `is_staff()`,
-- `o.buyer_id = auth.uid()`, etc.) — for `anon`, `auth.uid()` is NULL, so
-- every existing internal check already fails closed. None of these are
-- currently exploitable the way `support_messages_recent_count` was
-- (round 189/0095) — that function was the anomaly precisely because it
-- had NO internal ownership check, unlike every one of its siblings below.
-- This migration is defense-in-depth / hygiene: closing the same class of
-- footgun before a future function repeats 0093's mistake without also
-- repeating this round's dogfooding audit.
--
-- `marketplace_reviews_pin_reviewer_name()` is a trigger function (not
-- meant to be directly callable at all — matches 0095's treatment of
-- `support_messages_bump_ticket_updated_at`) and gets both `anon` and
-- `authenticated` revoked. `rls_auto_enable()` also appeared in the live
-- sweep but is a Supabase-platform-managed `event trigger` function (fires
-- on DDL, not REST-callable, not defined in this repo's own migrations at
-- all) — deliberately left untouched, out of scope for this schema.

revoke execute on function public.announcements_locked_fields(uuid) from anon;
revoke execute on function public.approve_shg_join_request(uuid, boolean) from anon;
revoke execute on function public.course_progress_locked_fields(uuid, uuid) from anon;
revoke execute on function public.current_role() from anon;
revoke execute on function public.current_shg_id() from anon;
revoke execute on function public.financial_ledger_previous_balance(uuid, text) from anon;
revoke execute on function public.is_leader_or_staff() from anon;
revoke execute on function public.is_staff() from anon;
revoke execute on function public.livelihood_activities_locked_fields(uuid) from anon;
revoke execute on function public.loans_locked_fields(uuid) from anon;
revoke execute on function public.loans_member_id(uuid) from anon;
revoke execute on function public.marketplace_order_locked_fields(uuid) from anon;
revoke execute on function public.marketplace_products_locked_fields(uuid) from anon;
revoke execute on function public.meeting_action_items_locked_fields(uuid) from anon;
revoke execute on function public.meeting_attendance_locked_fields(uuid) from anon;
revoke execute on function public.meetings_locked_fields(uuid) from anon;
revoke execute on function public.profile_is_active(uuid) from anon;
revoke execute on function public.profile_shg_id(uuid) from anon;
revoke execute on function public.profiles_locked_fields(uuid) from anon;
revoke execute on function public.savings_entries_locked_fields(uuid) from anon;
revoke execute on function public.scheme_applications_locked_fields(uuid) from anon;
revoke execute on function public.scheme_eligibility_met(uuid, uuid) from anon;
revoke execute on function public.shgs_current_row(uuid) from anon;
revoke execute on function public.submit_quiz_attempt(uuid, int[]) from anon;

revoke execute on function public.marketplace_reviews_pin_reviewer_name() from anon, authenticated;
