-- Auth flows + Router audit (batch 2) — found the INSERT-side twin of the
-- CRITICAL role-escalation bug 0009 fixed on UPDATE, still open on this
-- table's own INSERT path.
--
-- `profiles_insert_self` (0002_rls_policies.sql) is:
--
--   for insert with check (id = auth.uid());
--
-- This only proves the new row belongs to the caller — it places no
-- restriction at all on the VALUES that row is allowed to carry. `role`'s
-- own check constraint (0001_init_schema.sql) only restricts it to one of
-- the 5 valid enum strings; it does not restrict which caller may set it to
-- which value. So any freshly-authenticated user (anyone who's completed
-- phone OTP — i.e. anyone at all, since signup is open) can skip the app's
-- own `ProfileRepository.upsertMyProfile()` (which always hardcodes
-- `role: 'member'`) and instead call
-- `POST /rest/v1/profiles {"id": "<their own uid>", "name": "X", "role":
-- "admin"}` directly — creating their OWN first-ever profile row already at
-- `role = 'admin'`. This is a strictly easier, more direct version of the
-- exact bug 0009 called "CRITICAL": that fix closed the UPDATE path (an
-- existing member self-promoting), but a brand-new signup was never
-- blocked from simply being born an admin via INSERT instead — no
-- privilege escalation "step" needed at all, just one REST call on account
-- creation. Once `role = 'admin'`, every admin-gated table/UI in the app is
-- genuinely unlocked, same impact as 0009.
--
-- The same missing check also lets a fresh self-insert set `shg_id`
-- directly to any real SHG's id, self-declaring approved membership and
-- completely bypassing the `shg_join_requests` leader-approval workflow
-- `AppState.completeProfileSetup()`'s own doc comment describes as the only
-- legitimate way `shg_id` is meant to move ("membership only takes effect
-- once the SHG's leader approves the join request"). The app itself never
-- passes `shg_id` on this call (grepped `ProfileRepository.upsertMyProfile`
-- call sites — the one from `completeProfileSetup()` never supplies it), so
-- this is REST-only, unused-by-the-app surface, matching the disclosure
-- pattern of most of this session's other with-check fixes — but a real,
-- unclosed trust-boundary gap in the schema itself.
--
-- Round 15's INSERT-with-check sweep marked this policy "safe" — that sweep
-- was deliberately scoped to a narrower shape (does the row's own identity
-- column match the actor's identity, e.g. impersonating a DIFFERENT
-- person), which `id = auth.uid()` genuinely does satisfy. It never checked
-- the separate privilege-escalation shape 0009 had already found and fixed
-- on the UPDATE side of this very table — this migration closes that same
-- shape's INSERT twin, which slipped through every RLS sweep since.
--
-- Fix: mirror 0009's UPDATE-side fix. A self-insert may only ever create
-- itself as one of the two genuinely self-service roles (matching
-- `RoleSelectPage`'s own live-mode-only offering of Member/Leader), and
-- `shg_id` must be null on creation (matching the app's own "not set until
-- the leader approves" design) — no admin-insert-on-behalf-of-someone-else
-- branch is needed, unlike 0009's UPDATE fix, because `id = auth.uid()`
-- already makes this policy strictly self-only; no app code path ever has
-- one user INSERT another user's profile row.
drop policy if exists "profiles_insert_self" on public.profiles;

create policy "profiles_insert_self" on public.profiles
  for insert with check (
    id = auth.uid()
    and role in ('member', 'leader')
    and shg_id is null
  );
