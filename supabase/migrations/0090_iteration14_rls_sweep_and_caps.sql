-- Gap-hunt round 186 (iteration 14): four fresh audits (dogfooding round
-- 185's own fixes, Meetings/Attendance, Livelihood/Financial Ledger,
-- Support/Announcements/Payments) converged on the same two shapes this
-- session keeps re-discovering piecemeal — a "leader/staff acts on behalf
-- of a target row" policy missing a `profile_is_active()` check on that
-- target, and a `security invoker` RPC riding on an under-locked RLS
-- policy (the exact pre-0088 loans bug, found again on marketplace_orders)
-- — so this migration does one comprehensive sweep across every table each
-- audit flagged, rather than fixing them one at a time across more rounds.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. meeting_attendance: the leader-on-behalf-of AND is_staff() branches of
--    both INSERT and UPDATE never checked the target member's is_active —
--    round 185's own migration (0089) explicitly flagged this exact table
--    as having the identical shape already found for savings_entries/
--    livelihood_activities, but deliberately deferred it pending a
--    "dedicated, carefully-diffed pass" since the policy had already been
--    revised 5 times for unrelated lifecycle reasons. This is that pass.
--    `MeetingRepository.fetchRoster()` already filters to is_active=true,
--    so the app itself never legitimately sends a deactivated member_id —
--    closing this costs no real functionality, same as every other fix in
--    this series.
--
--    Also closes a second, independent gap the Meetings audit found: the
--    UPDATE policy's self-branch `with check` had no time-window
--    restriction at all (unlike INSERT's self-branch, which already
--    requires `meeting_date = current_date`) — once ANY attendance row
--    exists for a (meeting, member) pair, the member could directly PATCH
--    its `present` value at any later date, silently overriding a leader's
--    real record for a meeting from months ago with nothing to distinguish
--    it from a legitimate same-day correction.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meeting_attendance_insert_self_or_leader" on public.meeting_attendance;

create policy "meeting_attendance_insert_self_or_leader" on public.meeting_attendance
  for insert with check (
    (
      member_id = auth.uid()
      and exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.shg_id = public.current_shg_id()
          and m.status <> 'cancelled'
      )
    )
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and m.status <> 'cancelled'
        and public.current_role() = 'leader'
        and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
        and public.profile_is_active(meeting_attendance.member_id)
    )
    or (public.is_staff() and public.profile_is_active(meeting_attendance.member_id))
  );

drop policy if exists "meeting_attendance_update_self_or_leader" on public.meeting_attendance;

create policy "meeting_attendance_update_self_or_leader" on public.meeting_attendance
  for update using (
    member_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and m.status <> 'cancelled'
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  ) with check (
    (public.is_staff() and public.profile_is_active(meeting_attendance.member_id))
    or (
      (
        member_id = auth.uid()
        and exists (
          select 1 from public.meetings m
          where m.id = meeting_attendance.meeting_id
            and m.shg_id = public.current_shg_id()
            and m.status <> 'cancelled'
            and m.meeting_date = current_date
        )
      )
      or exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.shg_id = public.current_shg_id()
          and m.status <> 'cancelled'
          and public.current_role() = 'leader'
          and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
          and public.profile_is_active(meeting_attendance.member_id)
      )
    ) and (
      meeting_id = (select f.meeting_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
      and member_id = (select f.member_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. loans_update_leader_or_staff (0088, this session's own prior round):
--    the new lock never re-checked `shg_id` against its stored value for
--    the `is_staff()` branch — a leader's is incidentally pinned (their
--    own `current_shg_id()` is fixed and USING already required a match on
--    the old row), but nothing constrained it for staff. A malicious
--    crp/clf/admin session could `PATCH` a loan's `shg_id` to move it to a
--    different SHG entirely, breaking cross-tenant isolation.
--
--    loans_insert_self never got the `profile_is_active` check this
--    session added to every sibling self-insert table (savings, livelihood,
--    scheme_applications) — a deactivated member's still-valid session can
--    still land a fresh loan application in a leader's pending queue
--    (partially mitigated already: `approve_loan`, 0088, checks
--    `profile_is_active` before disbursement, so funds can't actually
--    reach her — but the application itself was never blocked at entry).
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "loans_update_leader_or_staff" on public.loans;
drop function if exists public.loans_locked_fields(uuid);

create or replace function public.loans_locked_fields(p_loan_id uuid)
returns table (
  shg_id uuid, amount numeric, purpose text, tenure_months int, created_at timestamptz,
  status text, outstanding numeric, emi numeric, disbursed_on date,
  next_due_date date, decided_by uuid, decided_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select l.shg_id, l.amount, l.purpose, l.tenure_months, l.created_at,
         l.status, l.outstanding, l.emi, l.disbursed_on,
         l.next_due_date, l.decided_by, l.decided_at
  from public.loans l
  where l.id = p_loan_id
    and (l.member_id = auth.uid() or l.shg_id = public.current_shg_id() or public.is_staff());
$$;

revoke all on function public.loans_locked_fields(uuid) from public;
grant execute on function public.loans_locked_fields(uuid) to authenticated;

create policy "loans_update_leader_or_staff" on public.loans
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  )
  with check (
    (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader')
      or public.is_staff()
    )
    and member_id = public.loans_member_id(loans.id)
    and public.loans_member_id(loans.id) <> auth.uid()
    and shg_id = (select f.shg_id from public.loans_locked_fields(loans.id) f)
    and amount = (select f.amount from public.loans_locked_fields(loans.id) f)
    and purpose = (select f.purpose from public.loans_locked_fields(loans.id) f)
    and tenure_months = (select f.tenure_months from public.loans_locked_fields(loans.id) f)
    and created_at = (select f.created_at from public.loans_locked_fields(loans.id) f)
    and status = (select f.status from public.loans_locked_fields(loans.id) f)
    and outstanding = (select f.outstanding from public.loans_locked_fields(loans.id) f)
    and emi is not distinct from (select f.emi from public.loans_locked_fields(loans.id) f)
    and disbursed_on is not distinct from (select f.disbursed_on from public.loans_locked_fields(loans.id) f)
    and next_due_date is not distinct from (select f.next_due_date from public.loans_locked_fields(loans.id) f)
    and decided_by is not distinct from (select f.decided_by from public.loans_locked_fields(loans.id) f)
    and decided_at is not distinct from (select f.decided_at from public.loans_locked_fields(loans.id) f)
  );

drop policy if exists "loans_insert_self" on public.loans;

create policy "loans_insert_self" on public.loans
  for insert with check (
    member_id = auth.uid()
    and public.profile_is_active(member_id)
    and shg_id = public.current_shg_id()
    and status = 'pending'
    and outstanding = amount
    and emi = 0
    and disbursed_on is null
    and next_due_date is null
    and created_at = now()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. marketplace_orders_update_seller_or_staff (0023): the `is_staff()`
--    branch had ZERO column lock — not `status`, not `buyer_id`, not
--    `amount`, not `product_id`, not `created_at`/`order_date` — the exact
--    "is_staff() branch left completely open" shape the loans bug (closed
--    in 0088) had. `advance_marketplace_order_status()` (0068) exists
--    specifically to stop a seller from skipping straight to 'delivered'
--    (which self-unlocks reviews with no real fulfillment behind it), but
--    since the seller branch here also leaves `status` unconstrained
--    (0023's own comment: "intentionally left free" — true for the
--    sequencing RPC's sake, but that RPC is `security invoker`, so this
--    policy is the only enforcement that actually exists), a direct PATCH
--    bypasses the RPC's sequencing guard entirely. Fix: lock every other
--    column for staff exactly as already done for the seller, and leave
--    `status` open for both (matching the RPC's own intended scope) — this
--    doesn't re-add the sequencing guard at the RLS layer (that's the
--    RPC's job and a separate, larger piece of work), it only closes the
--    unrelated, much larger hole of every OTHER column being rewritable.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "marketplace_orders_update_seller_or_staff" on public.marketplace_orders;

create policy "marketplace_orders_update_seller_or_staff" on public.marketplace_orders
  for update using (
    exists (select 1 from public.marketplace_products p where p.id = product_id and p.seller_id = auth.uid())
    or public.is_staff()
  )
  with check (
    (
      exists (select 1 from public.marketplace_products p where p.id = product_id and p.seller_id = auth.uid())
      or public.is_staff()
    )
    and product_id = (select l.product_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and buyer_id is not distinct from (select l.buyer_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and buyer_name = (select l.buyer_name from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and amount = (select l.amount from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and order_date = (select l.order_date from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and created_at = (select l.created_at from public.marketplace_order_locked_fields(marketplace_orders.id) l)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 4. Three more bare self-insert branches with the identical missing-
--    `profile_is_active` shape (0083's own comment already flagged this as
--    a known, larger, not-yet-finished sweep — this closes three more of
--    them): support_tickets, marketplace_reviews, payments.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "support_tickets_insert_self" on public.support_tickets;

create policy "support_tickets_insert_self" on public.support_tickets
  for insert with check (
    member_id = auth.uid()
    and public.profile_is_active(member_id)
    and status = 'open'
    and created_at = now()
    and (select count(*) from public.support_tickets t where t.member_id = auth.uid() and t.created_at > now() - interval '1 hour') < 10
  );

drop policy if exists "marketplace_reviews_insert_authenticated" on public.marketplace_reviews;

create policy "marketplace_reviews_insert_authenticated" on public.marketplace_reviews
  for insert with check (
    reviewer_id = auth.uid()
    and public.profile_is_active(reviewer_id)
    and exists (
      select 1 from public.marketplace_orders o
      where o.product_id = marketplace_reviews.product_id
        and o.buyer_id = auth.uid()
        and o.status = 'delivered'
    )
    and not exists (
      select 1 from public.marketplace_products p
      where p.id = marketplace_reviews.product_id
        and p.seller_id = auth.uid()
    )
  );

drop policy if exists "payments_insert_self_or_staff" on public.payments;

create policy "payments_insert_self_or_staff" on public.payments
  for insert with check ((member_id = auth.uid() or public.is_staff()) and public.profile_is_active(member_id));

-- ─────────────────────────────────────────────────────────────────────────
-- 5. announcement_reads: same shape, three policies (insert/update/delete
--    all self-only, per 0065's own hardening). A deactivated member's own
--    read-receipt bookkeeping is low real-world stakes, but the pattern is
--    identical and the fix is one line each — closing for completeness
--    of this sweep rather than leaving one bare self-branch un-audited.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "announcement_reads_write_self" on public.announcement_reads;
create policy "announcement_reads_write_self" on public.announcement_reads
  for insert with check (member_id = auth.uid() and public.profile_is_active(member_id));

drop policy if exists "announcement_reads_update_self" on public.announcement_reads;
create policy "announcement_reads_update_self" on public.announcement_reads
  for update using (member_id = auth.uid()) with check (member_id = auth.uid() and public.profile_is_active(member_id));

drop policy if exists "announcement_reads_delete_self" on public.announcement_reads;
create policy "announcement_reads_delete_self" on public.announcement_reads
  for delete using (member_id = auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- 6. announcements_select_scope_or_staff (0002): the platform-wide
--    (`shg_id is null`) branch was completely unconditional — not gated by
--    role, SHG match, OR active status, unlike the other two branches
--    (`shg_id = current_shg_id()` and `is_staff()`, both already
--    `is_active`-aware via those helpers' own definitions). A deactivated
--    member's still-valid session could read every platform-wide
--    announcement forever. This is the one item in this sweep that's a
--    read gap, not a write gap.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "announcements_select_scope_or_staff" on public.announcements;

create policy "announcements_select_scope_or_staff" on public.announcements
  for select using (
    (shg_id is null and public.profile_is_active(auth.uid()))
    or shg_id = public.current_shg_id()
    or public.is_staff()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 7. meeting_action_items: owner_id assignment has the same missing-
--    is_active shape (a leader could assign a to-do to a deactivated
--    member) — low stakes (nullable, no financial/attendance/audit-trail
--    weight, per 0015/0026/0047's own prior judgment on this table), fixed
--    for completeness of the sweep.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meeting_action_items_insert_leader_or_staff" on public.meeting_action_items;

create policy "meeting_action_items_insert_leader_or_staff" on public.meeting_action_items
  for insert with check (
    exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and (owner_id is null or (public.profile_shg_id(owner_id) = m.shg_id and public.profile_is_active(owner_id)))
    )
    or public.is_staff()
  );

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
        and (owner_id is null or (public.profile_shg_id(owner_id) = m.shg_id and public.profile_is_active(owner_id)))
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 8. meetings_insert_leader_or_staff (0064): the 7-day grace window fix
--    only ever added a lower bound on `meeting_date`; nothing capped how
--    far in the future one could be scheduled via direct REST (the app's
--    own date picker's `lastDate` is client-side only, 365 days out) — an
--    arbitrary-future-dated meeting has no real downstream corruption risk
--    the way backdating does, but a sane upper bound costs nothing.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meetings_insert_leader_or_staff" on public.meetings;

create policy "meetings_insert_leader_or_staff" on public.meetings
  for insert with check (
    ((shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff())
    and meeting_date >= (current_date - interval '7 days')
    and meeting_date <= (current_date + interval '365 days')
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 9. livelihood_activities: no upper-bound sanity cap on investment/
--    revenue, unlike every sibling monetary field (loans, savings_entries,
--    financial_ledger, payments all got one in earlier rounds). Same
--    ₹10,00,000 fat-finger-guard value used everywhere else in this schema.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.livelihood_activities add constraint livelihood_activities_amount_cap check (investment <= 1000000 and revenue <= 1000000);

-- ─────────────────────────────────────────────────────────────────────────
-- 10. financial_ledger: nothing stopped a single row from having both
--     `debit` and `credit` nonzero simultaneously — mathematically
--     satisfiable against the existing `balance = previous + credit -
--     debit` check, but nonsensical for a single-purpose ledger entry, and
--     `financial_ledger_page.dart`'s display (`isCredit = e.credit > 0`)
--     would silently hide a simultaneous debit that nonetheless moved the
--     shown balance. Only reachable via direct insert bypassing
--     `add_financial_ledger_entry` today (the RPC always zeroes one side),
--     but worth closing at the schema layer regardless.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.financial_ledger add constraint financial_ledger_debit_xor_credit check (debit = 0 or credit = 0);
