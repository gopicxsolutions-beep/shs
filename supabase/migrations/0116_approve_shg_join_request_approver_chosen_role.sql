-- Onboarding redesign: SHG selection is now mandatory at signup (client-side,
-- profile_setup_page.dart), and Role Select no longer offers a self-declared
-- 'leader' choice in live mode (router.dart now redirects any live-mode visit
-- to /role-select away). Every signup starts as 'member' with a pending
-- shg_join_requests row; becoming 'leader' is now entirely a decision made
-- by whoever approves that request, at approval time.
--
-- This replaces approve_shg_join_request's old 2-arg signature (migration
-- 0105) with a 3-arg one adding p_as_leader. The resulting role is now
-- derived SOLELY from the approver's explicit p_as_leader choice — never
-- from whatever value happens to already be sitting in profiles.role — which
-- is a strict improvement over the old reactive "reset leader back to member
-- on approval" guard: it structurally can't be defeated by a pre-set role
-- (e.g. a raw REST PATCH bypassing the app UI entirely; profiles_update_
-- self_or_admin's self branch still allows a caller with shg_id IS NULL to
-- set their own role to 'member' or 'leader' directly — see migration 0105's
-- own comment on that policy). The old policy is intentionally left as-is:
-- it's still exactly the right guard against that same direct-REST path,
-- just no longer the thing approve_shg_join_request reacts to.
--
-- Approving AS LEADER is staff-only (is_staff(): crp/clf/admin) — a peer
-- leader keeps her existing approve-as-member/reject authority over her own
-- SHG's queue (unchanged, spec'd: "Select SHG -> Approval by Leader"), but
-- minting a co-leader is a bigger action reserved for staff oversight,
-- consistent with every other is_staff() gate in this schema. This also
-- cleanly covers a brand-new SHG's very first leader with no extra plumbing:
-- nobody has current_role() = 'leader' for a leaderless SHG yet, so staff
-- (reachable via the existing /app/analytics/shg/:id/join-requests override
-- route) is already the only possible approver for that case.

drop function if exists public.approve_shg_join_request(uuid, boolean);

create or replace function public.approve_shg_join_request(p_request_id uuid, p_approve boolean, p_as_leader boolean default false)
returns void
language plpgsql
security definer
set search_path = 'public'
as $function$
declare
  v_request record;
begin
  select * into v_request from public.shg_join_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'join request not found';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'join request already decided (current status: %)', v_request.status;
  end if;

  if not (
    (public.current_role() = 'leader' and public.current_shg_id() = v_request.shg_id)
    or public.is_staff()
  ) then
    raise exception 'not authorized to decide this request';
  end if;

  if p_approve and p_as_leader and not public.is_staff() then
    raise exception 'only staff may approve a join request as leader';
  end if;

  if p_approve and not public.profile_is_active(v_request.member_id) then
    raise exception 'requester account is deactivated';
  end if;

  if p_approve then
    update public.profiles
      set shg_id = v_request.shg_id,
          role = case when p_as_leader then 'leader' else 'member' end
      where id = v_request.member_id;
    update public.shg_join_requests set status = 'approved', decided_at = now(), decided_by = auth.uid() where id = p_request_id;
  else
    update public.shg_join_requests set status = 'rejected', decided_at = now(), decided_by = auth.uid() where id = p_request_id;
  end if;
end;
$function$;

revoke all on function public.approve_shg_join_request(uuid, boolean, boolean) from public, anon;
grant execute on function public.approve_shg_join_request(uuid, boolean, boolean) to authenticated;
