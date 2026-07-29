-- Gap-hunt iteration 26 (round 199): self-correction, same round.
--
-- 0111's fix for `meeting_action_items_update_self_or_leader`'s staff
-- branch locked ALL FOUR of meeting_id/task/owner_id/due_date — copying
-- the SELF-branch's lock list (a member can only toggle `done` on her own
-- item; every other field is locked there) instead of the LEADER branch's
-- shape (which has never locked `task`/`due_date` — a leader has always
-- been able to freely correct a task's text or deadline for items in her
-- own SHG). Caught by this round's own live verification immediately
-- after applying 0111: a staff account correcting only `task` text (no
-- retargeting at all) was rejected with a bare RLS violation — an
-- over-restriction, not the forgery-prevention 0111 intended. The actual
-- concern (an unrestricted staff account rewriting which meeting/which
-- member an item belongs to) only requires locking `meeting_id`/
-- `owner_id`; `task`/`due_date` should remain as freely staff-editable as
-- they already are for leader, matching the same shape 0110 used for
-- `meeting_attendance`/`meetings` (only the identity/scope columns are
-- locked, not every column).
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meeting_action_items_update_self_or_leader" on public.meeting_action_items;

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
    (
      (
        public.is_staff()
        and meeting_id is not distinct from (select f.meeting_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
        and owner_id is not distinct from (select f.owner_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
      )
      or (
        owner_id = auth.uid()
        and public.profile_is_active(owner_id)
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
          and (owner_id is null or (public.profile_shg_id(owner_id) = m.shg_id and public.profile_is_active(owner_id)))
      )
    )
  );
