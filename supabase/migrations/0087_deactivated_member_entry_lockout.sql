-- Gap-hunt round 184: a leader/staff could still submit a savings entry or a
-- livelihood activity "on behalf of" a member whose account had already been
-- deactivated (0083_profiles_deactivation.sql). The Dart-side fix
-- (SavingsEntryPage._loadMembers) filters the picker dropdown to
-- `m.isActive` so this is no longer reachable through the app's own UI —
-- but per this repo's own security model (RLS is the real boundary, the
-- client-side check is UX only), nothing stopped a direct
-- `POST /rest/v1/savings_entries` (or `livelihood_activities`) with
-- `member_id` set to a deactivated member's id: `savings_insert_self_leader_
-- or_staff` / `livelihood_insert_self_leader_or_staff` (0038) only checked
-- `profile_shg_id(member_id) = shg_id` for the leader-on-behalf-of branch,
-- never whether that target member was still active. The self branch
-- (`member_id = auth.uid()`) is already safe — `current_shg_id()`/
-- `current_role()` both read `... where id = auth.uid() and is_active`, so
-- a deactivated member can never satisfy her own branch — this closes only
-- the leader-on-behalf-of gap.
--
-- meeting_attendance has the same leader-on-behalf-of shape
-- (`meeting_attendance_insert_self_or_leader`, most recently redefined in
-- 0042) but that policy has been revised 5 times across this migration
-- series for unrelated lifecycle reasons — extending it correctly deserves
-- its own dedicated, carefully-diffed pass rather than a rushed addition
-- here, so it is deliberately left for a future round.

create or replace function public.profile_is_active(p_member_id uuid)
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select coalesce((select p.is_active from public.profiles p where p.id = p_member_id), false);
$$;

revoke all on function public.profile_is_active(uuid) from public;
grant execute on function public.profile_is_active(uuid) to authenticated;

drop policy if exists "savings_insert_self_leader_or_staff" on public.savings_entries;

create policy "savings_insert_self_leader_or_staff" on public.savings_entries
  for insert with check (
    public.is_staff()
    or (
      status = 'pending'
      and entry_date = current_date
      and created_at = now()
      and (
        (member_id = auth.uid() and shg_id = public.current_shg_id())
        or (
          shg_id = public.current_shg_id()
          and public.current_role() = 'leader'
          and public.profile_shg_id(member_id) = shg_id
          and public.profile_is_active(member_id)
        )
      )
    )
  );

-- Rebuilt from 0066's definition (the latest prior revision — NOT 0038's,
-- which 0066 already superseded by adding the status/revenue lock below).
drop policy if exists "livelihood_insert_self_leader_or_staff" on public.livelihood_activities;

create policy "livelihood_insert_self_leader_or_staff" on public.livelihood_activities
  for insert with check (
    (
      (member_id = auth.uid() and shg_id = public.current_shg_id())
      or (
        shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and public.profile_shg_id(member_id) = shg_id
        and public.profile_is_active(member_id)
      )
      or public.is_staff()
    )
    and status = 'planned'
    and revenue = 0
  );
