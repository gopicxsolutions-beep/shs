-- Gap-hunt iteration 28: closes a CRITICAL privilege-escalation chain found
-- by dogfooding migration 0116 (the leader-onboarding redesign) rather than
-- treating it as settled once shipped.
--
-- 0116's own comment explicitly noted, and dismissed as harmless, that
-- `profiles_update_self_or_admin`'s self branch still lets any still-
-- unlinked caller (`shg_id is null`) PATCH their own `role` directly to
-- 'leader' via raw REST — reasoning that nothing "reacts" to a self-set
-- leader role anymore since `approve_shg_join_request` no longer resets it
-- back to 'member' on approval. That reasoning missed a second, ordinary
-- admin action that DOES react to it: `AdminRepository.assignShg()` (the
-- "Assign SHG" button in Admin > Users, the documented remedy for exactly
-- this profile shape — an unlinked leader/member) is a bare
-- `update({shg_id})` with no role check at all. Chained together: (1) a
-- member self-PATCHes her own `role` to 'leader' while `shg_id` is still
-- null — RLS-permitted; (2) an admin later clicks the ordinary "Assign SHG"
-- remedy on her profile, unaware it implies anything about role; (3) she now
-- has a real, RLS-backed `current_role()='leader' and current_shg_id()`
-- match — full leader authority over that SHG, obtained without
-- `approve_shg_join_request` or `is_staff()` ever being involved. This fully
-- defeats 0116's "approver-chosen role, never self-declared" model.
--
-- Fix: since Role Select no longer offers a self-declared Leader choice in
-- live mode (this exact redesign), 'leader' has no remaining legitimate
-- self-set caller — only 'member' needs to stay self-settable while
-- unlinked (a no-op for an already-member profile, and still lets a
-- genuinely-still-member row satisfy the WITH CHECK for unrelated column
-- edits, e.g. name/village, without RLS treating that as a role change).

drop policy if exists "profiles_update_self_or_admin" on public.profiles;

create policy "profiles_update_self_or_admin" on public.profiles
  for update using (id = auth.uid() or public.current_role() = 'admin')
  with check (
    public.current_role() = 'admin'
    or (
      id = auth.uid()
      and is_active
      and shg_id is not distinct from public.current_shg_id()
      and (role = public.current_role() or (role = 'member' and public.current_shg_id() is null))
      and mobile is not distinct from (select f.mobile from public.profiles_locked_fields(profiles.id) f)
      and created_at is not distinct from (select f.created_at from public.profiles_locked_fields(profiles.id) f)
      and is_active is not distinct from (select f.is_active from public.profiles_locked_fields(profiles.id) f)
      and deactivated_at is not distinct from (select f.deactivated_at from public.profiles_locked_fields(profiles.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- [HIGH] `approve_shg_join_request` never re-validated the requester's
-- CURRENT profile state at decision time — only that the request row itself
-- was still 'pending'. A pending request filed while the member was
-- role='member'/shg_id=null can sit unresolved while an unrelated admin
-- action (staff promotion via `updateUserRole`, or a manual `assignShg`)
-- changes her profile in the meantime; the eventual approve/reject then
-- silently overwrites whatever that later action set, with no warning to
-- either the approver or the affected member. Fixed by re-asserting the
-- requester is still in the exact state the request assumes immediately
-- before applying the decision, raising a clear, actionable exception
-- otherwise instead of silently clobbering.
-- ─────────────────────────────────────────────────────────────────────────

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

  if p_approve and not exists (
    select 1 from public.profiles where id = v_request.member_id and role = 'member' and shg_id is null
  ) then
    raise exception 'requester account has changed since this request was filed; ask them to submit a new request';
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
