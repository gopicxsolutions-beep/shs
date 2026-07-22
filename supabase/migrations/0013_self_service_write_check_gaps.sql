-- Follow-up to round 11's SQL migration audit, which found the
-- missing-`with check`-on-a-self-service-`for update`-policy bug shape twice
-- (`profiles_update_self_or_admin` fixed in 0009, `scheme_applications_
-- update_self_or_staff` fixed in 0012). This migration is a dedicated,
-- exhaustive re-check of EVERY `for update`/`for all` policy in the schema
-- (0002_rls_policies.sql, plus every later migration that touches a policy)
-- for the same shape — not just "is `with check` present", but "is it
-- actually present AND correct, i.e. does it really close off every
-- write-restricted column a lower-privilege actor shouldn't be able to
-- touch just because they're allowed to touch the row at all". Found 5 more
-- confirmed instances, all fixed below. Everything else was checked and is
-- either already correct (`with check` present and actually restrictive) or
-- has no restricted column for the gap to matter (see the session log for
-- the full table-by-table verdict list).
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1. shgs_update_leader_or_staff — leader could self-upgrade their own
--    SHG's `grade`, and reassign its `clf`/`vo` federation affiliation.
-- ─────────────────────────────────────────────────────────────────────────
-- `for update using ((id = current_shg_id() and current_role() = 'leader')
-- or is_staff())` with no `with check` at all. `grade` is an externally
-- assessed rating (bank/NABARD/CLF grading, shown read-only everywhere in
-- the app — AdminShgsPage never offers an editor for it, and grep confirms
-- ShgRepository has NO update method for `shgs` at all today; the "leader"
-- branch of this policy is 100% unused by any current app code path). Same
-- self-service-write-to-an-externally-assessed-field shape as the
-- `profiles.role` bug in 0009, just at the group level instead of the
-- individual level: a self-interested leader could directly
-- `PATCH /rest/v1/shgs?id=eq.<own-shg>` with `{"grade":"A"}` to inflate
-- their own group's grading (which gates loan/scheme eligibility elsewhere
-- in the product), or rewrite `clf`/`vo` to move their group between
-- federations/village-organizations without any actual administrative
-- decision behind it. Fix: keep the leader able to self-service the
-- ordinary descriptive/operational fields (name, address fields, bank
-- details — a real future "edit SHG profile" feature this policy was
-- clearly written to support), but pin `grade`/`clf`/`vo` to their current
-- stored values unless the actor is staff.
create or replace function public.shgs_current_row(p_id uuid)
returns table (grade text, clf text, vo text)
language sql
security definer
stable
set search_path = public
as $$
  select grade, clf, vo from public.shgs where id = p_id;
$$;

grant execute on function public.shgs_current_row(uuid) to authenticated;

drop policy if exists "shgs_update_leader_or_staff" on public.shgs;

create policy "shgs_update_leader_or_staff" on public.shgs
  for update using (
    (id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  )
  with check (
    public.is_staff()
    or (
      id = public.current_shg_id()
      and public.current_role() = 'leader'
      and grade is not distinct from (select r.grade from public.shgs_current_row(id) r)
      and clf is not distinct from (select r.clf from public.shgs_current_row(id) r)
      and vo is not distinct from (select r.vo from public.shgs_current_row(id) r)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. marketplace_orders_update_seller_or_staff — seller could rewrite an
--    order's amount/buyer/product after the fact, not just its status.
-- ─────────────────────────────────────────────────────────────────────────
-- `for update using (exists (... p.seller_id = auth.uid()) or is_staff())`
-- with no `with check`. The ONLY write this policy is meant to support is
-- `MarketplaceRepository.updateOrderStatus()` (`lib/pages/marketplace/
-- order_detail_page.dart`'s `_updateStatus` — the UI's "Update status" chip
-- row, gated to `canUpdateStatus` = seller-of-the-product-or-staff, and it
-- only ever sends `{'status': status}`). But with no `with check`, the same
-- seller could instead `PATCH` the SAME row with `{"amount": 1}` to
-- retroactively undercharge (or `{"amount": 99999}` to overcharge) an
-- already-placed order, reassign `buyer_id`/`buyer_name` to frame a
-- different member, or repoint `product_id` at a different (their own)
-- product entirely — 0008's fix already made the order's `amount` trusted
-- server-side at INSERT time specifically because client-supplied amounts
-- can't be trusted; this closes the same trust gap at UPDATE time. Fix:
-- `with check` requires every column except `status` to stay exactly what
-- it already was, unless the actor is staff.
drop policy if exists "marketplace_orders_update_seller_or_staff" on public.marketplace_orders;

create policy "marketplace_orders_update_seller_or_staff" on public.marketplace_orders
  for update using (
    exists (select 1 from public.marketplace_products p where p.id = product_id and p.seller_id = auth.uid())
    or public.is_staff()
  )
  with check (
    public.is_staff()
    or (
      exists (select 1 from public.marketplace_products p where p.id = product_id and p.seller_id = auth.uid())
      and product_id = (select o.product_id from public.marketplace_orders o where o.id = marketplace_orders.id)
      and buyer_id is not distinct from (select o.buyer_id from public.marketplace_orders o where o.id = marketplace_orders.id)
      and buyer_name = (select o.buyer_name from public.marketplace_orders o where o.id = marketplace_orders.id)
      and amount = (select o.amount from public.marketplace_orders o where o.id = marketplace_orders.id)
      and order_date = (select o.order_date from public.marketplace_orders o where o.id = marketplace_orders.id)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. support_tickets_update_self_or_staff — member could self-close/
--    self-resolve their own complaint, bypassing staff review entirely.
-- ─────────────────────────────────────────────────────────────────────────
-- `for update using (member_id = auth.uid() or is_staff())` with no
-- `with check` — the exact same shape as the `scheme_applications` bug
-- fixed in 0012. `status` (open/in_progress/resolved/closed) is meant to be
-- a staff-only workflow decision: `support_ticket_detail_page.dart` only
-- renders the status-change `PopupMenuButton` `if (isStaff...)` — a ticket's
-- own member never gets a status control in the UI at all, and
-- `SupportRepository` has exactly one update method (`updateStatus`), never
-- called from anywhere a plain member can reach. So the `member_id =
-- auth.uid()` branch of this policy is (like the `scheme_applications`
-- case) unused by any real app feature today, and only serves as an open
-- door for a member to `PATCH /rest/v1/support_tickets?id=eq.<own-ticket>`
-- with `{"status":"closed"}` (or "resolved") directly — making their own
-- unresolved complaint disappear from staff's queue with no actual
-- resolution, or manipulating support SLA/reporting. No app UI exercises
-- the member-self-update path, so restricting this policy to staff-only
-- closes the gap with zero loss of real functionality — matching 0012's
-- fix exactly.
drop policy if exists "support_tickets_update_self_or_staff" on public.support_tickets;

create policy "support_tickets_update_staff" on public.support_tickets
  for update using (public.is_staff()) with check (public.is_staff());

-- ─────────────────────────────────────────────────────────────────────────
-- 4. loans_update_leader_or_staff — an SHG leader who is ALSO a borrowing
--    member of her own group could approve (disburse) or reject her OWN
--    loan application, with no independent review at all.
-- ─────────────────────────────────────────────────────────────────────────
-- `for update using ((shg_id = current_shg_id() and current_role() =
-- 'leader') or is_staff())` with no `with check`. Unlike the other gaps in
-- this file, the "using" clause here is already role-gated (leader/staff,
-- not "any row owner"), so this one is real and LIVE-UI-reachable, not just
-- a direct-REST-only concern: `loans_insert_self` lets ANY member —
-- including one who also happens to be her SHG's `leader` — apply for her
-- own loan (`LoanRepository.apply()`), and `LoanApprovalPage` (`lib/pages/
-- loans/loan_approval_page.dart`, reachable from the Leader Dashboard's
-- "Approvals" tile) lists every `status = 'pending'` loan for
-- `fetchForShg(shgId)` with NO filter excluding the signed-in leader's own
-- applications, wired straight to `LoanRepository.approve()`/`reject()`.
-- That means a leader can open her own dashboard, see her own pending loan
-- application in the SAME approval queue as everyone else's, and tap
-- Approve — setting `status: 'active'`, `disbursed_on: today`, and her own
-- `emi`/`next_due_date` — unilaterally disbursing the SHG's pooled funds to
-- herself with no second reviewer, the same "self-approving your own
-- application" shape as the `scheme_applications` bug fixed in 0012, just
-- reachable without even needing a direct REST call. Fix: `with check`
-- keeps the leader able to approve/reject any OTHER member's loan in her
-- own SHG (the legitimate, intended workflow — SHG loan decisions are
-- ordinarily made by the leader/group), but requires staff involvement
-- specifically when the loan being decided is her own. Reads the loan's
-- CURRENT (pre-update) `member_id` via a self-referencing subquery — the
-- same technique 0009 already established for this exact "compare against
-- the row's existing stored value while updating that same row" need — so
-- it can't be defeated by also trying to reassign `member_id` in the same
-- update call.
drop policy if exists "loans_update_leader_or_staff" on public.loans;

create policy "loans_update_leader_or_staff" on public.loans
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  )
  with check (
    public.is_staff()
    or (
      shg_id = public.current_shg_id()
      and public.current_role() = 'leader'
      and member_id = (select l.member_id from public.loans l where l.id = loans.id)
      and (select l.member_id from public.loans l where l.id = loans.id) <> auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 5. payments_all_self_or_staff — `with check` was PRESENT but just as
--    buggy as missing: a member could flip their own failed/pending
--    payment to "success", or delete the record entirely.
-- ─────────────────────────────────────────────────────────────────────────
-- `for all using (member_id = auth.uid() or is_staff()) with check
-- (member_id = auth.uid() or is_staff())` — `with check` is present, but
-- identical to `using`, so it restricts nothing beyond row ownership (the
-- exact "present but buggy" variant of this bug class, not just "missing").
-- `for all` also covers DELETE, which has no restriction whatsoever beyond
-- ownership either. `PaymentRepository` only ever INSERTs a payment (the
-- (mock, until a real gateway key exists) processor's result is written
-- once, atomically, at charge time — see `pay()`); no client code anywhere
-- calls `.update()` or `.delete()` on `payments`. That means the entire
-- self-service UPDATE/DELETE surface is, today, unused by the app and only
-- reachable via a direct REST call — where a member could
-- `PATCH .../payments?id=eq.<own-row>` with `{"status":"success"}` to
-- record a failed/pending payment as having succeeded (the same
-- self-service-status-escalation shape as `scheme_applications`/
-- `support_tickets` above, just on a financial-transaction-outcome field
-- instead of an approval/workflow one), or `DELETE` it outright to erase
-- the record of a failed charge. Fix: split the single `for all` policy
-- into scoped ones — self-service stays for SELECT (view your own history)
-- and INSERT (record a fresh charge result, same as today), but UPDATE and
-- DELETE become staff-only, since no real feature needs a member to modify
-- or remove a payment record after the fact.
drop policy if exists "payments_all_self_or_staff" on public.payments;

create policy "payments_select_self_or_staff" on public.payments
  for select using (member_id = auth.uid() or public.is_staff());

create policy "payments_insert_self_or_staff" on public.payments
  for insert with check (member_id = auth.uid() or public.is_staff());

create policy "payments_update_staff" on public.payments
  for update using (public.is_staff()) with check (public.is_staff());

create policy "payments_delete_staff" on public.payments
  for delete using (public.is_staff());
