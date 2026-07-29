-- HOTFIX, discovered by round 187's own dogfooding audit within the same
-- session: round 187's migration (0091) "fixed" a TOCTOU race in
-- guard_last_admin_deactivation()/guard_last_admin_delete() by adding
-- `for update` directly onto a `select count(*) ...` query. That is
-- invalid SQL — Postgres rejects `FOR UPDATE` combined with an aggregate
-- function in the same SELECT (`0A000: FOR UPDATE is not allowed with
-- aggregate functions`) — confirmed by reproducing the exact query
-- directly against the live linked database. Because these are `language
-- plpgsql` function bodies, Postgres does not fully validate the body at
-- `CREATE OR REPLACE FUNCTION` time (only at first invocation), so
-- `supabase db push` succeeded with no error and this went live: since
-- 0091 was deployed, the BEFORE UPDATE/DELETE triggers on `profiles`
-- raised a hard Postgres error on EVERY attempt to change an active
-- admin's role away from 'admin', deactivate an active admin, or delete
-- an active admin row — not just the last-admin case this trigger exists
-- to guard, ALL of them, regardless of how many other admins existed.
-- `AdminUsersPage`'s role-change/deactivate actions wrap this in a bare
-- `catch (_)`, so this surfaced only as a generic "could not update"
-- toast with zero indication of the real cause.
--
-- Correct fix for locking rows while still computing an aggregate over
-- them: lock the individual rows in a subquery (a plain SELECT with no
-- aggregate, where FOR UPDATE is valid), then COUNT over that already-
-- locked result in the outer query (no FOR UPDATE needed at that level —
-- the rows are already locked by the inner SELECT for the remainder of
-- this transaction). This still closes the original TOCTOU race 0091
-- intended to fix; it just does so with syntax Postgres actually accepts.

create or replace function public.guard_last_admin_deactivation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_other_active_admins int;
begin
  if old.role = 'admin' and old.is_active and (new.role <> 'admin' or not new.is_active) then
    select count(*) into v_other_active_admins
    from (
      select id from public.profiles
      where role = 'admin' and is_active and id <> old.id
      for update
    ) locked_admins;

    if v_other_active_admins = 0 then
      raise exception 'cannot remove the last active admin account (deactivating, or changing role away from admin)';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.guard_last_admin_delete()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_other_active_admins int;
begin
  if old.role = 'admin' and old.is_active then
    select count(*) into v_other_active_admins
    from (
      select id from public.profiles
      where role = 'admin' and is_active and id <> old.id
      for update
    ) locked_admins;

    if v_other_active_admins = 0 then
      raise exception 'cannot delete the last active admin account';
    end if;
  end if;
  return old;
end;
$$;
