-- profiles: `mobile`/`created_at` were never locked in a member's own
-- self-update, unlike `shg_id`/`role` (0009/0023).
--
-- `profiles_update_self_or_admin`'s `with check` (0023, the current live
-- definition) constrains `shg_id` and `role` on a self-update but says
-- nothing about any other column — `mobile`/`created_at`/`avatar_color`
-- are wide open. The Flutter UI never exposes editing `mobile`
-- (`ProfileRepository.updateNameVillage` only ever sends name/village), but
-- a direct `PATCH /rest/v1/profiles?id=eq.<self>` with `{"mobile":"..."}`
-- succeeds. Since profiles are shared-read within an SHG
-- (`profiles_select_self_shg_or_staff`) and shown to the leader/CRP/admin,
-- a member could present a fabricated contact number to staff that no
-- longer matches the real `auth.users.phone` used for OTP login — a
-- social-engineering/data-integrity gap, the same class of bug 0023
-- already closed for `marketplace_orders.created_at` but missed here.
--
-- Fix: same locked-fields pattern as `marketplace_order_locked_fields`/
-- `meetings_locked_fields` — a `security definer` helper reading the
-- row's own stored values (bypassing RLS internally, avoiding the
-- self-referencing-subquery-on-its-own-table recursion this schema's own
-- CLAUDE.md warns about), pinning `mobile`/`created_at` to whatever they
-- already were for a non-admin self-update. `avatar_color` is left
-- unlocked — a cosmetic, non-sensitive field with no downstream trust
-- implication.

create or replace function public.profiles_locked_fields(p_id uuid)
returns table (mobile text, created_at timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select p.mobile, p.created_at from public.profiles p where p.id = p_id;
$$;

revoke all on function public.profiles_locked_fields(uuid) from public;
grant execute on function public.profiles_locked_fields(uuid) to authenticated;

drop policy if exists "profiles_update_self_or_admin" on public.profiles;

create policy "profiles_update_self_or_admin" on public.profiles
  for update using (id = auth.uid() or public.current_role() = 'admin')
  with check (
    public.current_role() = 'admin'
    or (
      id = auth.uid()
      and shg_id is not distinct from public.current_shg_id()
      and (
        role = public.current_role()
        or (role in ('member', 'leader') and public.current_shg_id() is null)
      )
      and mobile is not distinct from (select f.mobile from public.profiles_locked_fields(id) f)
      and created_at is not distinct from (select f.created_at from public.profiles_locked_fields(id) f)
    )
  );
