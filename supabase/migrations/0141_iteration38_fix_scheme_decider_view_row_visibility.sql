-- Fixes a mistake in 0139/0140's own fix, caught by live verification
-- before this was ever exposed to the app (never worked in production):
-- `scheme_decider_public` was created `security_invoker = true`, meaning
-- it enforces the SAME RLS as the base `profiles` table for the caller —
-- so once 0140 dropped `profiles_select_scheme_decider` (the only policy
-- granting a member row-visibility into her scheme decider's profile at
-- all), the view returned ZERO rows for the very case it exists to serve,
-- not just a narrower column set. Column-scoping and row-scoping can't
-- both be delegated to base-table RLS through an invoker view — there's
-- no way to say "visible via this view but not via the raw table" using
-- only a policy on the table itself.
--
-- Fixed by making the view `security_invoker = false` (runs as the view
-- owner, bypassing `profiles` RLS) and encoding the exact same row
-- condition the original policy had directly in the view's WHERE clause,
-- using `auth.uid()` (a session-level function, unaffected by which role
-- owns the view). This restores row-visibility for the legitimate case
-- while keeping the column list permanently capped at `id, name` — the
-- actual fix 0139/0140 intended.
create or replace view public.scheme_decider_public
with (security_invoker = false) as
  select p.id, p.name
  from public.profiles p
  where exists (
    select 1 from public.scheme_applications a
    where a.decided_by = p.id and a.member_id = auth.uid()
  );

grant select on public.scheme_decider_public to authenticated;
