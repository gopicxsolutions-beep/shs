-- Gap-hunt iteration 10 finding (dogfooding migration 0083's own
-- deactivation feature): nothing stopped an admin from deactivating the
-- only other admin account, or themselves as the last one — `setActive()`
-- (lib/repositories/admin_repository.dart) and `profiles_update_self_or_
-- admin`'s WITH CHECK both only require `current_role() = 'admin'`, with
-- no check for remaining active admins. Since 0083 made `current_role()`
-- resolve to null once `is_active = false`, deactivating the last admin
-- permanently locks the platform out of `current_role() = 'admin'` --
-- forever, with no in-app recovery (reactivation itself requires an admin
-- to perform it). This is a `BEFORE UPDATE` trigger, not an RLS `WITH
-- CHECK` clause, so the failure is an explicit, readable exception rather
-- than a silently-ignored 0-row update.

create or replace function public.guard_last_admin_deactivation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_other_active_admins int;
begin
  if old.role = 'admin' and old.is_active and not new.is_active then
    select count(*) into v_other_active_admins
    from public.profiles
    where role = 'admin' and is_active and id <> old.id;

    if v_other_active_admins = 0 then
      raise exception 'cannot deactivate the last active admin account';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists guard_last_admin_deactivation on public.profiles;
create trigger guard_last_admin_deactivation
  before update on public.profiles
  for each row execute function public.guard_last_admin_deactivation();
