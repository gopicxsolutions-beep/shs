-- Round 15's original INSERT-with-check sweep (0015_insert_check_scope_gaps.sql)
-- was deliberately scoped to one narrow shape: does the row's own
-- identity-bearing column (member_id/created_by/buyer_id) match the actor's
-- own identity/scope? It explicitly was NOT the "every column, not just the
-- one the bug report named" re-derivation that rounds 46-48
-- (0023/0024/0026) later applied to the UPDATE and DELETE sides. This
-- migration applies that same full re-derivation to INSERT: for every
-- non-admin/non-staff-only `for insert`/`for all` policy, read every column
-- 0001_init_schema.sql (+0004's shg_join_requests) actually declares on
-- that table, and ask whether an unconstrained one lets a caller who is
-- legitimately allowed to insert *something* insert a row that starts in a
-- state the app itself never produces and that causes real harm once other
-- code trusts it.
--
-- The dominant shape found (7 of 8 fixes below): a `status`/lifecycle
-- column that is meant to always start at ONE specific value, with every
-- other value only reachable through a real workflow (leader/staff review,
-- an RPC, a later UPDATE already gated staff-only) — but the INSERT policy
-- never said so, so a direct REST call (or a modified client) could insert
-- the row already in whatever end state it wanted, skipping the workflow
-- entirely. Verified against every relevant repository's actual `.insert()`
-- call site (grepped `lib/repositories/*.dart`) that the app itself NEVER
-- sends a value for any column locked below — every fix costs zero real
-- app functionality, matching this session's established pattern.
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1. loans_insert_self — THE headline finding. A member applying for her
--    own loan could insert it already `status = 'active'` (or `'closed'`),
--    with `disbursed_on`/`emi`/`next_due_date` set to anything, completely
--    skipping the pending -> leader-approves (`loans_update_leader_or_staff`,
--    leader/staff only) workflow this table exists to enforce.
-- ─────────────────────────────────────────────────────────────────────────
-- 0001: `loans (id, shg_id, member_id, purpose, amount, outstanding, emi,
-- tenure_months, disbursed_on, status, next_due_date, created_at)`. The
-- ONLY insert policy on this table is `for insert with check (member_id =
-- auth.uid() and shg_id = current_shg_id())` — no staff/leader
-- insert-on-behalf-of branch exists at all, so this single check is the
-- entire trust boundary. `LoanRepository.apply()` (lib/repositories/
-- loan_repository.dart) always sends exactly `status: 'pending'`,
-- `outstanding: amount`, `emi: 0`, and never sends `disbursed_on`/
-- `next_due_date`/`created_at` (left to their column defaults) — so a
-- direct `POST /rest/v1/loans` with `{"member_id": self, "shg_id": own,
-- "purpose": "x", "amount": 100000, "outstanding": 100000, "emi": 5000,
-- "tenure_months": 12, "status": "active", "disbursed_on": "2026-07-21",
-- "next_due_date": "2026-08-21"}` succeeds TODAY — a member can
-- self-disburse an already-"approved", already-EMI-scheduled loan against
-- her own SHG's pooled funds with zero independent review, worse than (and
-- upstream of) the self-approval bug 0013/0019/0023 already closed on the
-- UPDATE side. 0025's `outstanding <= amount` check bounds how much could
-- be claimed already-repaid, but does nothing to stop the `status`
-- escalation itself. Fix: lock every lifecycle/derived column to the exact
-- starting values `apply()` already always uses.
drop policy if exists "loans_insert_self" on public.loans;

create policy "loans_insert_self" on public.loans
  for insert with check (
    member_id = auth.uid()
    and shg_id = public.current_shg_id()
    and status = 'pending'
    and outstanding = amount
    and emi = 0
    and disbursed_on is null
    and next_due_date is null
    and created_at = now()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. scheme_applications_insert_self — identical shape to #1: a member
--    applying for a government scheme could insert her own application
--    already `status = 'approved'`, skipping staff review entirely.
-- ─────────────────────────────────────────────────────────────────────────
-- 0015 reviewed this policy and marked it "verified correct: member_id =
-- auth.uid(), nothing more needed" — that verdict was scoped to the
-- identity-column shape only. 0001: `scheme_applications (id, scheme_id,
-- member_id, status, applied_on)`, `status` check `('not_applied',
-- 'applied', 'under_review', 'approved', 'rejected')` default `'applied'`.
-- 0012 already closed the UPDATE-side self-approval bug on this exact table
-- (`scheme_applications_update_staff`, staff-only) precisely because
-- self-approving a scheme application is a real privilege-escalation shape
-- — but the INSERT policy (`for insert with check (member_id =
-- auth.uid())`) never touched `status`, so the same escalation is reachable
-- one step earlier: insert the row already `'approved'` instead of
-- UPDATE-ing it there afterward. `SchemeRepository.apply()` (lib/
-- repositories/scheme_repository.dart) always sends exactly `status:
-- 'applied'`; never a custom `applied_on`. Fix: lock both to the app's own
-- always-used starting values.
drop policy if exists "scheme_applications_insert_self" on public.scheme_applications;

create policy "scheme_applications_insert_self" on public.scheme_applications
  for insert with check (
    member_id = auth.uid()
    and status = 'applied'
    and applied_on = current_date
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. support_tickets_insert_self — a member could insert her own complaint
--    already `status = 'resolved'`/`'closed'`, silently undermining 0013's
--    own UPDATE-side fix for this exact table (self-close via PATCH) via a
--    different path (self-close via POST instead).
-- ─────────────────────────────────────────────────────────────────────────
-- 0013 restricted `support_tickets_update_self_or_staff` to staff-only
-- specifically because "a member could self-close/self-resolve their own
-- complaint... making it disappear from staff's queue with no actual
-- resolution". But `support_tickets_insert_self` (`for insert with check
-- (member_id = auth.uid())`) never touched `status` — so the exact same
-- outcome 0013 closed off is still reachable by inserting a BRAND NEW
-- ticket already `status = 'closed'` instead of updating an existing one:
-- a fabricated "already resolved" complaint that never actually surfaces in
-- staff's `open`/`in_progress` queue, useful for satisfying an external
-- "was this addressed?" review with a record that was never really
-- reviewed. `SupportRepository.createTicket()` never sends `status` (relies
-- on the column default `'open'`). Fix: lock `status` to `'open'`, and
-- `created_at` to `now()` (unlocked otherwise, a backdated ticket could
-- make a just-filed complaint look neglected for weeks in a staff queue
-- sorted/reported by age — same class of timestamp-falsification concern
-- 0023/0024 already closed for `marketplace_orders`/`announcements`).
drop policy if exists "support_tickets_insert_self" on public.support_tickets;

create policy "support_tickets_insert_self" on public.support_tickets
  for insert with check (
    member_id = auth.uid()
    and status = 'open'
    and created_at = now()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 4. savings_insert_self_leader_or_staff — a member (or a leader posting on
--    a member's behalf) could insert a deposit already `status =
--    'verified'`, skipping the leader-verification step entirely — and
--    unlike the already-disclosed `savings_entries_update_leader_or_staff`
--    gap (a LEADER self-verifying HER OWN previously-submitted entry via
--    UPDATE, judged lower-stakes and left as the team's own call), this is
--    a genuinely different, wider path: ANY plain member, with no leader
--    role at all, self-declaring her own brand-new deposit pre-verified at
--    the moment of creation.
-- ─────────────────────────────────────────────────────────────────────────
-- 0001: `savings_entries (id, shg_id, member_id, entry_date, amount, mode,
-- frequency, status, created_at)`, `status` check `('verified', 'pending')`
-- default `'pending'`. `SavingsRepository.addEntry()` always sends exactly
-- `status: 'pending'`, never a custom `entry_date`/`created_at`. Fix: lock
-- `status`/`entry_date`/`created_at` inside both the self and leader
-- branches (staff branch left fully open, matching this schema's
-- consistent staff-trust model). Locking `entry_date` to `current_date` (in
-- addition to closing a real backdating vector — an entry moved into an
-- earlier/later reporting month could manipulate the SHG's savings-
-- compliance figures that feed `shgs.grade`, which in turn gates loan/
-- scheme eligibility per 0013's own comment) also keeps this fix internally
-- consistent with fix #8 below, whose `balance` check assumes same-day
-- entries land in real chronological order.
drop policy if exists "savings_insert_self_leader_or_staff" on public.savings_entries;

create policy "savings_insert_self_leader_or_staff" on public.savings_entries
  for insert with check (
    public.is_staff()
    or (
      status = 'pending'
      and entry_date = current_date
      and created_at = now()
      and (
        member_id = auth.uid()
        or (
          shg_id = public.current_shg_id()
          and public.current_role() = 'leader'
          and public.profile_shg_id(member_id) = shg_id
        )
      )
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 5. marketplace_orders_insert_authenticated — a buyer could insert an
--    order already `status = 'delivered'`, and/or backdate `order_date`/
--    `created_at`, none of which 0015's `buyer_id`-only fix touched.
-- ─────────────────────────────────────────────────────────────────────────
-- 0001+0002: `marketplace_orders (id, product_id, buyer_name, amount,
-- status, order_date, created_at, buyer_id)`, `status` check `('new',
-- 'packed', 'shipped', 'delivered')` default `'new'`.
-- `MarketplaceRepository.placeOrder()` always sends exactly `status:
-- 'new'`, never a custom `order_date`/`created_at`. Leaving `status` open
-- lets a buyer fabricate an order that already looks fulfilled, bypassing
-- the seller's own fulfillment queue/workflow
-- (`marketplace_orders_update_seller_or_staff` is the only path meant to
-- ever advance `status`). Leaving `order_date`/`created_at` open repeats,
-- one step earlier, the exact falsify-the-timestamp-to-manipulate-ordering
-- shape 0023 already closed for this table's UPDATE path (`created_at`) and
-- 0018 already closed for `order_date` — closing the UPDATE side while
-- leaving INSERT open only forces the same attack into "backdate at
-- creation" instead of "backdate afterward", not actually closing anything.
-- Fix: lock all three to the app's own always-used starting values.
-- (Disclosed, NOT fixed in this migration: `amount` is still not tied to
-- `marketplace_products.price` by any `with check` — only the app's own
-- `decrement_product_stock` RPC-then-insert convention keeps it honest in
-- practice, never RLS itself. A hard `amount = (select price ...)` equality
-- check was considered, but the RPC call and this INSERT are two separate
-- round trips from the Dart client with no shared transaction — a
-- concurrent, legitimate seller price edit landing in that narrow window
-- would make an otherwise-honest order fail the check outright, the same
-- "atomicity, not a check-and-maybe-fail race" preference 0011 already
-- established for this exact class of problem. Left as a known, narrower
-- gap for the team's own judgment rather than trading a rare false-failure
-- for closing an even rarer direct-REST fraud path that also requires
-- bypassing stock decrement entirely to pull off.)
drop policy if exists "marketplace_orders_insert_authenticated" on public.marketplace_orders;

create policy "marketplace_orders_insert_authenticated" on public.marketplace_orders
  for insert with check (
    auth.role() = 'authenticated'
    and (buyer_id is null or buyer_id = auth.uid())
    and status = 'new'
    and order_date = current_date
    and created_at = now()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 6. shg_join_requests_insert_self — a member could self-insert her own
--    join request already `status = 'approved'`/`'rejected'`, with
--    `decided_by` set to any real profile id and `decided_at`/
--    `requested_at` backdated/forged.
-- ─────────────────────────────────────────────────────────────────────────
-- 0004: `shg_join_requests (id, member_id, shg_id, status, requested_at,
-- decided_at, decided_by)`, `status` check `('pending', 'approved',
-- 'rejected')` default `'pending'`. `ShgJoinRequestRepository.submit()`
-- only ever sends `member_id`/`shg_id`. This table's `status`/`decided_*`
-- columns don't by themselves grant real SHG access (that only ever
-- happens through `approve_shg_join_request()`, security definer, which
-- re-derives its own authorization independently and ignores whatever is
-- already stored on the request row) — but a fabricated `'approved'`/
-- `'rejected'` row with `decided_by` pointed at a REAL leader's profile id
-- is a genuine misattribution: it makes it look like a specific named
-- person made a decision on this request they never actually saw, visible
-- to that same leader and to staff via `shg_join_requests_select_self_
-- leader_or_staff`, and backdating `requested_at` lets a member jump the
-- front of the leader's own approval queue (`fetchPendingForShg` orders by
-- `requested_at` ascending). Fix: lock all four to the app's own
-- always-used starting shape (pending, not yet decided, requested now).
drop policy if exists "shg_join_requests_insert_self" on public.shg_join_requests;

create policy "shg_join_requests_insert_self" on public.shg_join_requests
  for insert with check (
    member_id = auth.uid()
    and status = 'pending'
    and requested_at = now()
    and decided_at is null
    and decided_by is null
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 7. announcements_insert_leader_or_staff — `created_at` was never locked
--    on the INSERT side, only on UPDATE (0024).
-- ─────────────────────────────────────────────────────────────────────────
-- 0024 already established WHY `created_at` matters on this specific table
-- (unlike `meetings`/`livelihood_activities`/`marketplace_products`/
-- `announcement_reads`, explicitly left alone in that same migration):
-- announcements is a genuinely cross-membership, shared, sorted-by-
-- `created_at` feed, not a single-owner-scoped resource. 0024 closed the
-- UPDATE path (a leader falsifying an EXISTING post's timestamp
-- afterward) but split the policy into separate INSERT/UPDATE specifically
-- BECAUSE a locked-fields lookup can't work for a brand-new row — and, in
-- doing so, left the new `announcements_insert_leader_or_staff` with no
-- `created_at` check at all. That means the exact same feed-order
-- manipulation 0024 closed on UPDATE is still open one step earlier: post
-- a new announcement with `created_at` set far in the future (pins it at
-- the top of every member's feed indefinitely) or far in the past (buries
-- it immediately). `AnnouncementRepository.post()` never sends
-- `created_at`. Fix: require it equal `now()`, same technique as every
-- other `created_at`/`entry_date`/`order_date` lock in this migration —
-- safe because a column's own `default now()` and a `with check (col =
-- now())` in the same INSERT statement observe the identical
-- transaction-start `now()` value when the caller omits the column.
drop policy if exists "announcements_insert_leader_or_staff" on public.announcements;

create policy "announcements_insert_leader_or_staff" on public.announcements
  for insert with check (
    (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
    )
    and created_by = auth.uid()
    and created_at = now()
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 8. financial_ledger_insert_leader_or_staff — `balance` was never tied to
--    the actual running total; a direct REST insert (bypassing
--    `add_financial_ledger_entry`, 0011) could post ANY `balance` value,
--    corrupting the SHG's whole cashbook running total with no trace.
-- ─────────────────────────────────────────────────────────────────────────
-- 0015 locked `created_by` but never `balance`/`entry_date`/`created_at`.
-- `balance` is supposed to always equal `previous_balance_for_this_
-- (shg_id, entry_type) + credit - debit` (`add_financial_ledger_entry`'s
-- own formula) — 0016 made `debit`/`credit` non-negative, but nothing
-- stops `balance` itself from being an unrelated number. Since
-- `FinancialRepository.addEntry()` always goes through the RPC (or, if
-- undeployed, an equivalent client-side two-step using the IDENTICAL
-- lookup/formula — see its own `PGRST202` fallback), and neither path ever
-- sends a custom `entry_date`, closing this at the RLS layer costs nothing
-- real while closing a genuine direct-REST path to silently desync every
-- later chained balance in this schema's own audit ledger (the exact harm
-- 0011/0014's own comments already call out this table as existing to
-- prevent). `entry_date` is also locked to `current_date` — both because
-- the app never sends a custom one, and because it keeps the `balance`
-- formula below internally consistent (it looks up the single most
-- recently POSTED row for the same (shg_id, entry_type), which only means
-- "most recent" if entries can't be backdated ahead of it).
--
-- Note: this check mirrors the RPC's own lookup query exactly, so the
-- legitimate RPC (and its fallback) keep working unchanged. It does NOT by
-- itself add back the RPC's advisory-lock serialization for a hypothetical
-- concurrent DIRECT (non-RPC) insert — that residual race already existed
-- before this fix (a direct insert was never covered by the RPC's lock to
-- begin with) and is strictly no worse than today; closing it fully would
-- need moving this table's INSERT behind a security-definer function
-- entirely, a larger architectural change out of scope for a `with check`
-- fix.
create or replace function public.financial_ledger_previous_balance(p_shg_id uuid, p_entry_type text)
returns numeric
language sql
security definer
stable
set search_path = public
as $$
  select balance
  from public.financial_ledger
  where shg_id = p_shg_id
    and entry_type = p_entry_type
    and (p_shg_id = public.current_shg_id() or public.is_staff())
  order by entry_date desc, created_at desc
  limit 1;
$$;

revoke all on function public.financial_ledger_previous_balance(uuid, text) from public;
grant execute on function public.financial_ledger_previous_balance(uuid, text) to authenticated;

drop policy if exists "financial_ledger_insert_leader_or_staff" on public.financial_ledger;

create policy "financial_ledger_insert_leader_or_staff" on public.financial_ledger
  for insert with check (
    (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
    )
    and created_by = auth.uid()
    and entry_date = current_date
    and created_at = now()
    and balance = coalesce(public.financial_ledger_previous_balance(shg_id, entry_type), 0) + credit - debit
  );

-- ─────────────────────────────────────────────────────────────────────────
-- Explicitly re-derived and disclosed, NOT fixed here (judgment calls,
-- matching this session's established precedent of disclosing-but-not-
-- unilaterally-fixing lower-stakes or architecturally-harder gaps):
--
-- * loan_payments_insert_related — a member (for her own loan) or a leader
--   (for her SHG's) can insert a `loan_payments` row directly, bypassing
--   `record_loan_payment()` (0011) entirely, with an `amount` never
--   reconciled against `loans.outstanding` at all (a direct insert doesn't
--   also decrement `outstanding` the way the RPC does atomically). This
--   creates a payment-history entry that doesn't correspond to any real
--   change in what's still owed. Judged lower-severity than the 8 fixes
--   above: `loan_detail_page.dart`/`member_dashboard.dart`'s "repaid so
--   far" figures are computed from `amount - outstanding` (per 0025's own
--   note), not from summing `loan_payments`, so a fabricated row doesn't
--   itself inflate any balance actually trusted elsewhere — the exposure
--   is a misleading repayment-history list, not a corrupted balance. A real
--   fix needs the INSERT itself routed through a security-definer function
--   that also updates `loans.outstanding` atomically (the same shape as
--   `record_loan_payment`, just reachable from a plain `with check` isn't
--   possible since RLS can't touch a second table) — an architectural
--   change out of scope for this column-lock-focused migration.
-- * livelihood_write_self_leader_or_staff — `status` (`'planned'` default)
--   is insertable at any of its 3 values directly, identical shape to the
--   fixed cases above, but judged materially lower-stakes: this is a
--   member's own self-reported business activity log with no
--   leader/staff approval workflow to bypass in the first place (unlike
--   loans/scheme_applications/savings), and no other party's interests are
--   at stake in what stage SHE calls her own livelihood activity — same
--   "self-certification is the feature" reasoning 0024 already applied to
--   `course_progress.certified`.
-- * payments_insert_self_or_staff — `status` is genuinely self-supplied by
--   design in this codebase's current mock-payment-gateway architecture
--   (`PaymentRepository.pay()` computes the (mocked) charge result
--   CLIENT-SIDE and writes it directly — there is no server-side gateway
--   yet to be the real trust boundary). Locking `status` here would break
--   the app's own only payment flow today. Matches round 15/47's own
--   documented plan: the real fix is a `payment-webhook-handler`-style
--   Edge Function trust boundary once a real gateway is wired in, not an
--   RLS `with check` on the client-writable table.
-- * audit_log_insert_self — `actor_id = auth.uid()` already prevents
--   misattributing a fabricated entry to someone else; `action`/`entity`/
--   `entity_id`/`meta` are unconstrained, but the table is 100%
--   REST-only/unused-by-the-app surface today (grepped `lib/` — nothing
--   ever writes to `audit_log`), and any fabricated row is self-attributed
--   noise only an admin reading their own actor's history would see, not a
--   spoofable third-party record. Lower priority than the 8 fixes above.
-- ─────────────────────────────────────────────────────────────────────────
