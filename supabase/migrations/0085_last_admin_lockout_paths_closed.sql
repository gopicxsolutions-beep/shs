-- Gap-hunt iteration 11 finding (dogfooding round 182's own last-admin
-- guard, migration 0084): that trigger only fired when `is_active` flipped
-- to false. Two other paths had the exact same "nobody can ever resolve
-- current_role() = 'admin' again" effect, both completely unguarded:
--
--   1. AdminRepository.updateUserRole() does a bare `update({'role': ...})`
--      with no remaining-admin check -- demoting the last admin (or the
--      last admin demoting themselves) away from 'admin' while is_active
--      stays true never matched 0084's `not new.is_active` condition.
--   2. profiles_delete_admin (0002) lets any admin DELETE any profile,
--      including the last admin's own row or the only other admin's, with
--      no admin-count check at all -- worse than deactivation since it's
--      also irreversible (the profile row is gone, not just flagged).
--
-- Fix: broaden the existing UPDATE guard's condition from "was active,
-- deactivated" to "was an active admin, no longer is" (covers both a role
-- change away from 'admin' AND deactivation in one check), and add a new
-- BEFORE DELETE trigger closing the second path.

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
    from public.profiles
    where role = 'admin' and is_active and id <> old.id;

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
    from public.profiles
    where role = 'admin' and is_active and id <> old.id;

    if v_other_active_admins = 0 then
      raise exception 'cannot delete the last active admin account';
    end if;
  end if;
  return old;
end;
$$;

drop trigger if exists guard_last_admin_delete on public.profiles;
create trigger guard_last_admin_delete
  before delete on public.profiles
  for each row execute function public.guard_last_admin_delete();
