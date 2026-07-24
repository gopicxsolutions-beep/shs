-- ─────────────────────────────────────────────────────────────────────────
-- meeting_action_items_write_related: close the owner_id cross-SHG gap
--
-- 0015/0024/0026 explicitly disclosed and left this open on the basis that
-- `meeting_mom_page.dart`'s `_addActionItem()` never actually passed an
-- `ownerId` — a leader could set `owner_id` to any profile in the entire
-- system (not just her own SHG's members), but since the app never
-- exercised that parameter, the practical exposure was considered nil.
--
-- That justification is now stale: `meeting_mom_page.dart` has since grown
-- a real "Assign to" picker (`_roster = await _repo.fetchRoster(shgId)`)
-- that lets a leader assign a task to any real member of her own SHG, and
-- `_addActionItem()` (`meeting_repository.dart`) does pass that `ownerId`
-- straight through to `insert()`. The client-side picker already restricts
-- choices to same-SHG members, but per this project's own security model
-- (RLS is the authorization boundary; client-side restriction is UX only),
-- a direct REST call could still set `owner_id` to a profile in a
-- completely different SHG. This closes that gap so the RLS layer actually
-- matches what the UI already promises, mirroring the same-SHG check
-- already used for savings/attendance/livelihood member assignment
-- (`profile_shg_id(member_id) = m.shg_id`).
--
-- `owner_id is null` is still allowed (an unassigned action item) — this
-- only constrains a *non-null* owner to be a member of the meeting's own
-- SHG. The self branch (`owner_id = auth.uid()`) and the DELETE scope are
-- both left exactly as they were: DELETE was already explicitly reviewed
-- and left as `for all` in 0026 on its own disclosed low-stakes reasoning
-- (nullable to-do assignment, not financial/attendance/audit-trail data),
-- and that judgment isn't being re-litigated here.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meeting_action_items_write_related" on public.meeting_action_items;

create policy "meeting_action_items_write_related" on public.meeting_action_items
  for all using (
    owner_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and (owner_id is null or public.profile_shg_id(owner_id) = m.shg_id)
    )
    or public.is_staff()
  ) with check (
    owner_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and (owner_id is null or public.profile_shg_id(owner_id) = m.shg_id)
    )
    or public.is_staff()
  );
