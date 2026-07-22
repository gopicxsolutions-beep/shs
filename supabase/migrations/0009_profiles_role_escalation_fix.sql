-- CRITICAL SECURITY FIX — self-service privilege escalation to Admin.
--
-- Found live, this session (2026-07-20): `profiles_update_self_or_admin`
-- (0002_rls_policies.sql) is:
--
--   for update using (id = auth.uid() or public.current_role() = 'admin');
--
-- with no `with check` at all — meaning it has no column-level restriction.
-- Any authenticated user can update ANY column on their OWN profile row,
-- including `role` and `shg_id`. `lib/pages/auth/role_select_page.dart`
-- (part of ordinary onboarding, shown to every new signup) renders all 5
-- roles — including Administrator — and calls `AppState.setRole()` →
-- `ProfileRepository.updateRole()` → a plain self-targeted
-- `UPDATE profiles SET role = ? WHERE id = auth.uid()`. Nothing server-side
-- ever stopped this from setting role to 'admin'. This is also directly
-- exploitable without the app at all: any authenticated user's own JWT can
-- call `PATCH /rest/v1/profiles?id=eq.<their-own-uid>` with
-- `{"role":"admin"}` and it succeeds today. Once `role = 'admin'`, every
-- admin-gated table (`schemes_write_admin`, `shgs_delete_admin`,
-- `profiles_delete_admin`, etc.) and every admin-only UI in
-- lib/pages/admin/*.dart is genuinely unlocked.
--
-- A client-side stopgap shipped in the same session (RoleSelectPage now
-- only offers Member/Leader in live mode; AppState.setRole() throws for
-- crp/clf/admin) closes the in-app UI path, but does NOT close the direct
-- REST API path — this migration is the actual fix and should be applied
-- as soon as possible. **This session could not deploy it**: the
-- authenticated `supabase` CLI here only has access to a different project
-- ("humanproof"), not this app's actual live project
-- (`pccbwfmlhpvieetetrpx` per earlier session notes in
-- docs/DEVELOPMENT_PROGRESS.md) — apply via `supabase db push` (or the
-- Supabase Dashboard's SQL editor) against the real project urgently.
--
-- Fix: replace the policy with a `with check` that only lets a self-update
-- through if (a) `role` isn't actually changing (reads the caller's own
-- CURRENT role via the already-existing `current_role()` security-definer
-- helper — this is the same helper every other policy in this schema
-- already trusts for permission checks, not a new mechanism) or is being
-- set to the two genuinely self-service roles (member/leader), AND (b)
-- `shg_id` isn't changing (it's only ever meant to move via the
-- `approve_shg_join_request()` RPC — security definer, so it bypasses RLS
-- entirely and is unaffected by this change — or an admin's own update,
-- covered by the first branch below). An actual admin (current_role() =
-- 'admin') keeps full unrestricted access, matching the original policy's
-- intent for admin-driven changes (role promotions via Admin → Users,
-- SHG assignment via the new "Assign SHG" feature).

drop policy if exists "profiles_update_self_or_admin" on public.profiles;

create policy "profiles_update_self_or_admin" on public.profiles
  for update using (id = auth.uid() or public.current_role() = 'admin')
  with check (
    public.current_role() = 'admin'
    or (
      id = auth.uid()
      and (role = public.current_role() or role in ('member', 'leader'))
      and shg_id is not distinct from public.current_shg_id()
    )
  );
