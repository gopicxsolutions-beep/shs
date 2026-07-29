-- Gap-hunt iteration 24 (round 197): closes a LOW-severity defense-in-depth
-- gap found by the Onboarding/Certificates/Voice Assistant audit.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [LOW] `shg_join_requests_delete_self_pending` had no `profile_is_
--    active()` gate — unlike its sibling `shg_join_requests_insert_self`,
--    which migration 0105 explicitly hardened with exactly this check for
--    deactivated members. A deactivated member could still DELETE her own
--    pending join request via direct REST. Not reachable through the app
--    UI (the router's `accountDeactivated` redirect fires before any
--    onboarding screens for a deactivated account), so this is defense-in-
--    depth only — impact is self-deleting an inconsequential own row, not
--    a privilege gain — but it's the same gap-class 0105 was written to
--    close on this exact table, just missed on the DELETE policy.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "shg_join_requests_delete_self_pending" on public.shg_join_requests;

create policy "shg_join_requests_delete_self_pending" on public.shg_join_requests
  for delete using (member_id = auth.uid() and status = 'pending' and public.profile_is_active(member_id));
