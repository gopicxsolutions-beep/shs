-- HOTFIX, caught by this same session's own live verification of 0101's
-- `savings_insert_self_leader_or_staff` before considering it complete:
-- the staff branch reused `profile_shg_id(member_id) = shg_id`, copied
-- from the leader branch immediately above it — but `profile_shg_id()`
-- only ever returns a match when the target's `shg_id` equals the
-- CALLER's own `shg_id` (it's built specifically for the leader's "is this
-- member in MY SHG" case, per its own definition). Staff have no `shg_id`
-- of their own (platform-wide), so that call always returns `null` for a
-- staff caller — making the fixed staff branch reject every insert,
-- including a legitimate one, live-confirmed via a real rolled-back
-- transaction before this hotfix. Fixed by looking up the target member's
-- real `shg_id` directly instead of reusing the leader-scoped helper —
-- safe because `is_staff()` callers can already read any profile row via
-- `profiles_select_self_shg_or_staff`.

drop policy if exists "savings_insert_self_leader_or_staff" on public.savings_entries;

create policy "savings_insert_self_leader_or_staff" on public.savings_entries
  for insert with check (
    status = 'pending'
    and entry_date = current_date
    and created_at = now()
    and (
      (member_id = auth.uid() and shg_id = public.current_shg_id())
      or (shg_id = public.current_shg_id() and public.current_role() = 'leader' and public.profile_shg_id(member_id) = shg_id and public.profile_is_active(member_id))
      or (public.is_staff() and shg_id = (select p.shg_id from public.profiles p where p.id = member_id) and public.profile_is_active(member_id))
    )
  );
