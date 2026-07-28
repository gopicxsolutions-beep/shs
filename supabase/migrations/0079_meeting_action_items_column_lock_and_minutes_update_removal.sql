-- Two more gaps found in a fresh audit of meeting minutes/action items,
-- the one part of the Meetings module never previously reviewed.
--
-- 1. meeting_action_items_write_related's self branch (owner_id =
--    auth.uid()) had NO column lock -- the app only ever sends
--    {'done': done} (MeetingRepository.toggleActionItem), but a direct
--    REST PATCH let an assigned member rewrite what her own task literally
--    says, push her due date out arbitrarily, or re-point meeting_id at
--    any meeting system-wide (the leader branch already checks
--    m.shg_id = current_shg_id(); the self branch never did). Every
--    sibling table already got this locked-fields treatment (livelihood
--    0036, meeting_attendance 0035/0042, meetings 0071) -- this was the
--    one holdout. Split the single "for all" policy into per-command
--    policies so UPDATE's self branch can be locked to `done` only while
--    the leader/staff branch keeps its existing free-edit power; INSERT
--    is leader/staff-only (the app never self-inserts an action item -- a
--    member is only ever assigned one, never creates her own). SELECT
--    keeps working unchanged via the separate, pre-existing
--    meeting_action_items_select_related policy (0002 -- same-SHG read,
--    untouched by this migration, already broader than anything this fix
--    needs to add). DELETE keeps its prior scope unchanged (DELETE's
--    "for all"-open self-branch was already explicitly reviewed and left
--    as low-stakes in 0026 -- not part of this fix).
--
-- 2. meeting_minutes_update_leader_or_staff let any leader/staff silently
--    rewrite the decisions array of any PAST meeting's minutes, with no
--    updated_at/audit column on the table at all -- contradicting this
--    table's own actual usage: MeetingRepository never calls .update() on
--    meeting_minutes, only saveMinutes() (insert) and
--    fetchLatestMinutes() (read). Dropping the dead UPDATE policy matches
--    actual usage and closes the "corrupts the historical record of what
--    was actually decided, silently" risk 0026 already reasoned about for
--    DELETE on this same table.

create or replace function public.meeting_action_items_locked_fields(p_id uuid)
returns table (meeting_id uuid, task text, owner_id uuid, due_date date)
language sql
security definer
stable
set search_path = public
as $$
  select a.meeting_id, a.task, a.owner_id, a.due_date
  from public.meeting_action_items a
  where a.id = p_id;
$$;

revoke all on function public.meeting_action_items_locked_fields(uuid) from public;
grant execute on function public.meeting_action_items_locked_fields(uuid) to authenticated;

drop policy if exists "meeting_action_items_write_related" on public.meeting_action_items;

create policy "meeting_action_items_insert_leader_or_staff" on public.meeting_action_items
  for insert with check (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and (owner_id is null or public.profile_shg_id(owner_id) = m.shg_id)
    )
    or public.is_staff()
  );

create policy "meeting_action_items_update_self_or_leader" on public.meeting_action_items
  for update using (
    owner_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  ) with check (
    public.is_staff()
    or (
      owner_id = auth.uid()
      and meeting_id is not distinct from (select f.meeting_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
      and task is not distinct from (select f.task from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
      and owner_id is not distinct from (select f.owner_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
      and due_date is not distinct from (select f.due_date from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
    )
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and (owner_id is null or public.profile_shg_id(owner_id) = m.shg_id)
    )
  );

create policy "meeting_action_items_delete_related" on public.meeting_action_items
  for delete using (
    owner_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  );

drop policy if exists "meeting_minutes_update_leader_or_staff" on public.meeting_minutes;
