-- Gap-hunt round 188 (iteration 16): the Support Tickets module's own
-- dedicated round, promised across rounds 184/185/186/187 and re-verified
-- unchanged each time. Closes 5 of the 6 previously-deferred items in one
-- pass (FAQ-as-hardcoded-content stays intentional, per docs/SRS.md).
-- Also fixes a missing `created_at` lock on `payments` found by this
-- round's payments audit, the same insert-lifecycle-lock pattern every
-- other self-insert table already got in migration 0027's original sweep.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. support_tickets: add updated_at (bumped whenever the ticket itself
--    changes, AND whenever a new message arrives on it — see the trigger
--    on support_messages below) so a resolved-then-replied-to ticket
--    actually resurfaces in the (now updated_at-ordered) staff queue
--    instead of staying buried at its original creation-time position
--    forever. Also adds category (member-set at creation, matching the
--    existing enum-via-check-constraint convention used throughout this
--    schema) and priority (staff-only, defaults to 'normal', matches the
--    existing status/decision trust shape — staff is already unconditionally
--    trusted with `status`).
-- ─────────────────────────────────────────────────────────────────────────

alter table public.support_tickets add column if not exists updated_at timestamptz not null default now();
alter table public.support_tickets add column if not exists category text not null default 'general'
  check (category in ('general', 'savings', 'loans', 'meetings', 'livelihood', 'marketplace', 'payments', 'account', 'other'));
alter table public.support_tickets add column if not exists priority text not null default 'normal'
  check (priority in ('low', 'normal', 'high', 'urgent'));

drop trigger if exists support_tickets_set_updated_at on public.support_tickets;
create trigger support_tickets_set_updated_at before update on public.support_tickets
  for each row execute function public.set_updated_at();

-- A new message doesn't touch support_tickets itself, so the trigger above
-- alone can't see it — security definer is required since the replying
-- member/staff account has no other RLS grant to write support_tickets.
create or replace function public.support_messages_bump_ticket_updated_at()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.support_tickets set updated_at = now() where id = new.ticket_id;
  return new;
end;
$$;

drop trigger if exists support_messages_bump_ticket_updated_at_trigger on public.support_messages;
create trigger support_messages_bump_ticket_updated_at_trigger
  after insert on public.support_messages
  for each row execute function public.support_messages_bump_ticket_updated_at();

-- ─────────────────────────────────────────────────────────────────────────
-- 2. support_tickets_insert_self: pin the two new columns at creation —
--    member picks category (the column CHECK constraint already validates
--    the value, no extra RLS check needed for that), priority stays
--    staff-only (pinned to 'normal' here, matching every other lifecycle-
--    locked INSERT policy in this schema that keeps a staff-decided field
--    out of the member's own hands at creation time).
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "support_tickets_insert_self" on public.support_tickets;

create policy "support_tickets_insert_self" on public.support_tickets
  for insert with check (
    member_id = auth.uid()
    and public.profile_is_active(member_id)
    and status = 'open'
    and priority = 'normal'
    and created_at = now()
    and (select count(*) from public.support_tickets t where t.member_id = auth.uid() and t.created_at > now() - interval '1 hour') < 10
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. support_tickets_update_staff -> ..._staff_or_self_reopen: the actual
--    fix for "no reopen path for a resolved ticket." Design: a member can
--    only move resolved/closed -> open (never directly to resolved/closed
--    — that stays staff-only, the exact self-approval-shaped gap migration
--    0013 already closed once and must not reopen). No cooldown/lock
--    column needed — the state machine self-throttles: reopening consumes
--    the "resolved" state, so a member can't reopen again until staff
--    resolves it a second time.
--
--    Interaction with migration 0024's own reasoning: 0024 explicitly
--    judged subject/description/member_id/created_at safe to leave
--    unlocked on this policy specifically BECAUSE it was 100%-staff-only
--    at the time ("no non-admin/non-owner actor... for a column-lock gap
--    to matter against"). The moment a member-writable branch is added,
--    that precondition no longer holds — so this migration locks those
--    columns for BOTH branches now (staff's own `status`/`priority`/
--    `resolved_by` freedom is untouched, matching 0024's still-valid
--    staff-trust reasoning for those specific fields).
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "support_tickets_update_staff" on public.support_tickets;
drop function if exists public.support_tickets_locked_fields(uuid);

create or replace function public.support_tickets_locked_fields(p_id uuid)
returns table (resolved_by uuid, subject text, description text, created_at timestamptz, member_id uuid, priority text)
language sql
stable security definer
set search_path = public
as $$
  select t.resolved_by, t.subject, t.description, t.created_at, t.member_id, t.priority
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
      and (
        resolved_by is not distinct from (select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f)
        or resolved_by = auth.uid()
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
      and resolved_by is not distinct from (select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 4. support_messages: no length cap or rate limit at all, unlike its
--    sibling support_tickets (subject <=150/description <=1000 + 10/hour,
--    migration 0078) — messages are the higher-frequency write (one per
--    reply vs. one per complaint), so this was the more exposed gap of the
--    two. Also pins created_at (found while re-verifying this item: 0038's
--    own adversarial insert-sweep covered sender_id/membership on this
--    policy but never created_at, so a message could be backdated/
--    postdated, corrupting the thread's displayed chronological order).
--    Rate-limit window is shorter/looser than support_tickets' 10/hour —
--    messages are the intended high-frequency conversational channel.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.support_messages add constraint support_messages_body_length_check check (char_length(body) <= 500);

drop policy if exists "support_messages_insert_related" on public.support_messages;

create policy "support_messages_insert_related" on public.support_messages
  for insert with check (
    sender_id = auth.uid()
    and public.profile_is_active(sender_id)
    and created_at = now()
    and exists (
      select 1 from public.support_tickets t
      where t.id = support_messages.ticket_id and (t.member_id = auth.uid() or public.is_staff())
    )
    and (
      select count(*) from public.support_messages m
      where m.sender_id = auth.uid() and m.created_at > now() - interval '10 minutes'
    ) < 20
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 5. payments_insert_self_or_staff: missing `created_at = now()` lock,
--    unlike essentially every sibling self-insert policy hardened during
--    migration 0027's original insert-lifecycle-lock sweep (loans,
--    savings_entries, meetings, scheme_applications, marketplace_orders,
--    shg_join_requests, support_tickets, announcements all got this same
--    lock) — payments never did. A direct insert could backdate/postdate
--    a fabricated payment in the member's own displayed history. The
--    separate question of whether the is_staff() branch should also be
--    restricted to the caller's own member_id (vs. staff recording a
--    payment on a member's behalf, a plausible real assisted-payment
--    workflow for this app's target users) is a design decision, not
--    fixed here — deliberately deferred rather than rushed.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "payments_insert_self_or_staff" on public.payments;

create policy "payments_insert_self_or_staff" on public.payments
  for insert with check (
    (member_id = auth.uid() or public.is_staff())
    and public.profile_is_active(member_id)
    and created_at = now()
  );
