-- Follow-up to 0139: the new `scheme_decider_public` view only closes the
-- leak for callers going through it — `profiles_select_scheme_decider`
-- itself was left in place, so a direct `/rest/v1/profiles?id=eq.<decider>`
-- query still returned the decider's full row exactly as before. The
-- Dart app (`scheme_repository.dart`) no longer relies on this policy at
-- all — it queries `scheme_decider_public` instead — so the policy is now
-- both unnecessary and the actual remaining half of the leak. Dropped.
drop policy if exists "profiles_select_scheme_decider" on public.profiles;
