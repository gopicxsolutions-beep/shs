-- Gap-hunt iteration 9 finding: no account-deactivation/offboarding path
-- exists anywhere for a member who leaves a real SHG (moves away, disputes,
-- etc.) — `profiles` had no `is_active`/`deactivated_at` column at all, and
-- AdminUsersPage only offered "change role"/"assign SHG", never suspend or
-- remove. The only alternative was either leaving a stale live account
-- forever, or hard-deleting the `profiles` row — which, per this schema's
-- own `on delete restrict` FKs (0063/0072/etc, added specifically to stop
-- exactly this), would either fail outright or destroy historical loan/
-- savings/ledger rows.
--
-- Fix: `is_active`/`deactivated_at` columns, admin-only writable (same
-- locked-fields pattern as mobile/created_at, 0076 — extended here rather
-- than duplicated). The actual enforcement is server-side and blanket: the
-- 4 identity-resolution helper functions every RLS policy in this schema
-- calls (`current_role()`, `current_shg_id()`, `is_staff()`,
-- `is_leader_or_staff()`) now resolve to null/false for a deactivated
-- caller, which transitively blocks every policy branch keyed on role or
-- SHG membership — not just a client-side hidden button. `profile_shg_id()`
-- (looks up a DIFFERENT member's shg_id, not the caller's own identity) is
-- deliberately left unchanged — it's used to check facts about a referenced
-- member elsewhere, not the acting caller's own authorization boundary.
--
-- Documented scope limit (not a silent gap — this round's fix, not a full
-- lockdown): a handful of RLS policies additionally have a bare
-- `member_id = auth.uid()`/`created_by = auth.uid()` branch alongside the
-- role/shg_id branches this closes (e.g. a member reading/writing their own
-- savings_entries row). Those direct-identity branches are NOT gated by
-- is_active by this migration — closing every one of those individually
-- across the schema is a larger, separate pass. This migration's own
-- app-level companion (AppState.accountDeactivated forcing a sign-out to a
-- dedicated screen) is the practical mitigation for that gap: a deactivated
-- user's own client stops calling the app at all once detected, rather than
-- relying solely on the RLS boundary for every single table.

alter table public.profiles add column if not exists is_active boolean not null default true;
alter table public.profiles add column if not exists deactivated_at timestamptz;

drop policy if exists "profiles_update_self_or_admin" on public.profiles;

drop function if exists public.profiles_locked_fields(uuid);

create or replace function public.profiles_locked_fields(p_id uuid)
returns table (mobile text, created_at timestamptz, is_active boolean, deactivated_at timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select p.mobile, p.created_at, p.is_active, p.deactivated_at from public.profiles p where p.id = p_id;
$$;

revoke all on function public.profiles_locked_fields(uuid) from public;
grant execute on function public.profiles_locked_fields(uuid) to authenticated;

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
      and is_active is not distinct from (select f.is_active from public.profiles_locked_fields(id) f)
      and deactivated_at is not distinct from (select f.deactivated_at from public.profiles_locked_fields(id) f)
    )
  );

create or replace function public.current_role()
returns text
language sql
security definer
stable
set search_path = public
as $$
  select role from public.profiles where id = auth.uid() and is_active;
$$;

create or replace function public.current_shg_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select shg_id from public.profiles where id = auth.uid() and is_active;
$$;

create or replace function public.is_staff()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce((select role in ('crp', 'clf', 'admin') from public.profiles where id = auth.uid() and is_active), false);
$$;

create or replace function public.is_leader_or_staff()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce((select role in ('leader', 'crp', 'clf', 'admin') from public.profiles where id = auth.uid() and is_active), false);
$$;
