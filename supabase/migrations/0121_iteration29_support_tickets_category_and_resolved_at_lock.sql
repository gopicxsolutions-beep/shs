-- Gap-hunt iteration 29: Support module full sweep, 2 real column-lock gaps
-- on support_tickets.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [MEDIUM] `category` was never locked on UPDATE, contradicting this
--    exact migration round's (0093) own stated design ("category:
--    member-set at creation"). Every other immutable column on this table
--    (subject/description/created_at/member_id/resolved_by) is locked in
--    `support_tickets_locked_fields()`/the WITH CHECK below — `category`
--    was simply missed. Not reachable via the app's own UI today
--    (`SupportRepository` never sends `category` on update), but a direct
--    REST PATCH by the ticket's own member or staff can silently rewrite
--    it post-creation.
--
-- 2. [MEDIUM] `resolved_at` was likewise never locked on UPDATE, unlike
--    its sibling `resolved_by`. Migration 0053's `support_tickets_stamp_
--    resolved_at()` trigger only overwrites `resolved_at := now()` when
--    `resolved_by` is NEWLY set (`new.resolved_by is distinct from old.
--    resolved_by`) — on any OTHER update (notably the member's own reopen
--    transition, which never touches resolved_by at all), whatever
--    `resolved_at` value the client supplied passes straight through
--    unchecked, since no WITH CHECK pin existed for it at all. A member
--    could forge an arbitrary `resolved_at` on her own already-resolved
--    ticket the moment she reopens it — corrupting exactly the audit-trail
--    integrity 0052/0053 were built to guarantee for `resolved_by` but
--    left open for its own timestamp sibling.
--
--    Locking it is straightforward BECAUSE of how the trigger already
--    works: the trigger is `before update`, so by the time this WITH CHECK
--    evaluates, `new.resolved_at` has ALREADY been correctly overwritten
--    to the server's own `now()` whenever `resolved_by` newly changed —
--    the client's submitted value for that case is irrelevant, already
--    discarded. So the check only needs to pin `resolved_at` to its prior
--    value on updates that do NOT change `resolved_by`; when `resolved_by`
--    IS changing, the trigger has already guaranteed `resolved_at` is
--    correct regardless of what the client sent, mirroring exactly the
--    same "or resolved_by is changing" escape hatch `resolved_by` itself
--    already uses in the staff branch.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "support_tickets_update_staff_or_self_reopen" on public.support_tickets;
drop function if exists public.support_tickets_locked_fields(uuid);

create or replace function public.support_tickets_locked_fields(p_id uuid)
returns table (resolved_by uuid, subject text, description text, created_at timestamptz, member_id uuid, priority text, category text, resolved_at timestamptz)
language sql
stable security definer
set search_path = public
as $$
  select t.resolved_by, t.subject, t.description, t.created_at, t.member_id, t.priority, t.category, t.resolved_at
  from public.support_tickets t
  where t.id = p_id
    and (t.member_id = auth.uid() or public.is_staff());
$$;

revoke all on function public.support_tickets_locked_fields(uuid) from public;
grant execute on function public.support_tickets_locked_fields(uuid) to authenticated;

create policy "support_tickets_update_staff_or_self_reopen" on public.support_tickets
  for update using (
    public.is_staff()
    or (member_id = auth.uid() and status in ('resolved', 'closed') and public.profile_is_active(member_id))
  )
  with check (
    (
      public.is_staff()
      and subject = (select f.subject from public.support_tickets_locked_fields(support_tickets.id) f)
      and description is not distinct from (select f.description from public.support_tickets_locked_fields(support_tickets.id) f)
      and created_at = (select f.created_at from public.support_tickets_locked_fields(support_tickets.id) f)
      and member_id = (select f.member_id from public.support_tickets_locked_fields(support_tickets.id) f)
      and category = (select f.category from public.support_tickets_locked_fields(support_tickets.id) f)
      and (
        resolved_by is not distinct from (select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f)
        or resolved_by = auth.uid()
      )
      and (
        resolved_at is not distinct from (select f.resolved_at from public.support_tickets_locked_fields(support_tickets.id) f)
        or resolved_by is distinct from (select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f)
      )
    )
    or (
      member_id = auth.uid()
      and public.profile_is_active(member_id)
      and status = 'open'
      and priority = (select f.priority from public.support_tickets_locked_fields(support_tickets.id) f)
      and subject = (select f.subject from public.support_tickets_locked_fields(support_tickets.id) f)
      and description is not distinct from (select f.description from public.support_tickets_locked_fields(support_tickets.id) f)
      and created_at = (select f.created_at from public.support_tickets_locked_fields(support_tickets.id) f)
      and member_id = (select f.member_id from public.support_tickets_locked_fields(support_tickets.id) f)
      and category = (select f.category from public.support_tickets_locked_fields(support_tickets.id) f)
      and resolved_by is not distinct from (select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f)
      and resolved_at is not distinct from (select f.resolved_at from public.support_tickets_locked_fields(support_tickets.id) f)
    )
  );
