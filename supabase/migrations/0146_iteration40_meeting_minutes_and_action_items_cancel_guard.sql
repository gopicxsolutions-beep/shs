-- Gap-hunt iteration 40: a fresh Meeting Minutes/Action Items audit found
-- these two tables never inherited the meetings cancel-guard chain
-- (0042, 0110, 0129, 0133, 0134, 0135) that already locks `meetings`
-- itself and `meeting_attendance` against writes once a meeting is
-- cancelled. `meeting_minutes_insert_leader_or_staff` and both
-- `meeting_action_items_insert_leader_or_staff`/`_update_self_or_leader`
-- only ever checked SHG scope, role, and owner assignment — never the
-- parent meeting's `status`.
--
-- Live-verified (rolled back): a leader inserted a fabricated decision
-- into `meeting_minutes` for a cancelled meeting (succeeded); the same
-- leader added a brand-new task assignment via `meeting_action_items` for
-- that cancelled meeting (succeeded); the assigned member then toggled
-- that item's `done` to true (succeeded). UI-reachable, not REST-only —
-- `meeting_mom_page.dart` never checks `meeting.status` before rendering
-- these forms. This directly contradicts 0026's own rationale for this
-- table: "this schema's durable record of what a meeting decided" — a
-- leader could fully author governance history for a meeting the app
-- itself has recorded as never having happened.
--
-- Fixed by requiring `m.status <> 'cancelled'` for INSERT/UPDATE on both
-- tables, and DELETE on `meeting_action_items` for the same reason
-- (reshaping a cancelled meeting's record by removing an item is the same
-- risk as adding/editing one) — applied uniformly to every branch
-- (leader and staff alike), same as every other guard in this chain.
drop policy if exists "meeting_minutes_insert_leader_or_staff" on public.meeting_minutes;
create policy "meeting_minutes_insert_leader_or_staff" on public.meeting_minutes
  for insert with check (
    (
      (exists (select 1 from public.meetings m where m.id = meeting_minutes.meeting_id and m.shg_id = public.current_shg_id() and public.current_role() = 'leader'))
      or public.is_staff()
    )
    and exists (select 1 from public.meetings m where m.id = meeting_minutes.meeting_id and m.status <> 'cancelled')
    and created_at = now()
  );

drop policy if exists "meeting_action_items_insert_leader_or_staff" on public.meeting_action_items;
create policy "meeting_action_items_insert_leader_or_staff" on public.meeting_action_items
  for insert with check (
    (
      (exists (
        select 1 from public.meetings m
        where m.id = meeting_action_items.meeting_id and m.shg_id = public.current_shg_id() and public.current_role() = 'leader'
          and (meeting_action_items.owner_id is null or (public.profile_shg_id(meeting_action_items.owner_id) = m.shg_id and public.profile_is_active(meeting_action_items.owner_id)))
      ))
      or (public.is_staff() and exists (
        select 1 from public.meetings m
        where m.id = meeting_action_items.meeting_id
          and (meeting_action_items.owner_id is null or exists (
            select 1 from public.profiles p where p.id = meeting_action_items.owner_id and p.shg_id = m.shg_id and p.is_active
          ))
      ))
    )
    and exists (select 1 from public.meetings m where m.id = meeting_action_items.meeting_id and m.status <> 'cancelled')
  );

drop policy if exists "meeting_action_items_update_self_or_leader" on public.meeting_action_items;
create policy "meeting_action_items_update_self_or_leader" on public.meeting_action_items
  for update using (
    owner_id = auth.uid()
    or (exists (select 1 from public.meetings m where m.id = meeting_action_items.meeting_id and m.shg_id = public.current_shg_id() and public.current_role() = 'leader'))
    or public.is_staff()
  ) with check (
    (
      (public.is_staff()
        and meeting_id is not distinct from (select f.meeting_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
        and owner_id is not distinct from (select f.owner_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f))
      or (owner_id = auth.uid() and public.profile_is_active(owner_id)
        and meeting_id is not distinct from (select f.meeting_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
        and task is not distinct from (select f.task from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
        and owner_id is not distinct from (select f.owner_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
        and due_date is not distinct from (select f.due_date from public.meeting_action_items_locked_fields(meeting_action_items.id) f))
      or (exists (
        select 1 from public.meetings m
        where m.id = meeting_action_items.meeting_id and m.shg_id = public.current_shg_id() and public.current_role() = 'leader'
          and (meeting_action_items.owner_id is null or (public.profile_shg_id(meeting_action_items.owner_id) = m.shg_id and public.profile_is_active(meeting_action_items.owner_id)))
      ))
    )
    and exists (select 1 from public.meetings m where m.id = meeting_action_items.meeting_id and m.status <> 'cancelled')
  );

drop policy if exists "meeting_action_items_delete_related" on public.meeting_action_items;
create policy "meeting_action_items_delete_related" on public.meeting_action_items
  for delete using (
    (
      (exists (select 1 from public.meetings m where m.id = meeting_action_items.meeting_id and m.shg_id = public.current_shg_id() and public.current_role() = 'leader'))
      or (public.is_staff() and owner_id is distinct from auth.uid())
    )
    and exists (select 1 from public.meetings m where m.id = meeting_action_items.meeting_id and m.status <> 'cancelled')
  );
