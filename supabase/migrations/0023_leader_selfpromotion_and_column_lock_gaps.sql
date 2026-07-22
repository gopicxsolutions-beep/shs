-- Adversarial re-verification pass (round 46) on 4 previously "fixed"
-- CRITICAL/security policies (0009, 0022, 0019, 0018). Tried hard to break
-- each; two hold up cleanly against direct single/multi-statement attacks
-- (see the session log for the full trace), but this migration closes two
-- genuine, real gaps found while re-deriving the other two against EVERY
-- column/workflow they touch, not just the ones their own fix comments
-- called out.
--
-- ─────────────────────────────────────────────────────────────────────────
-- 1 & 2. profiles_update_self_or_admin (0009) + approve_shg_join_request
--    (0004) — a self-declared "leader" can become a REAL, unilaterally-
--    privileged leader of an SHG she has no actual standing to lead,
--    without ever tripping 0009's own `with check` directly. Two distinct
--    paths, both closed below.
-- ─────────────────────────────────────────────────────────────────────────
-- Path A — direct self-promotion of an ALREADY-approved membership. 0009's
-- `with check` only constrains `shg_id` to stay byte-for-byte unchanged
-- within the SAME update statement; it never looks at whether `shg_id` is
-- currently null (still onboarding) or already points at a real, leader/
-- staff-approved SHG. So a ordinary member who was properly approved into
-- SHG S weeks ago (`role = 'member'`, `shg_id = S`) can simply
-- `PATCH /rest/v1/profiles?id=eq.<self>` with `{"role":"leader"}` (same
-- request shape `ProfileRepository.updateRole()` already sends) — `role`
-- moves to 'leader' (one of the two self-service roles 0009 allows
-- unconditionally) while `shg_id` stays `S` (unchanged, so the check's
-- `is not distinct from` clause is trivially satisfied). Every leader-gated
-- policy in this schema (`loans_update_leader_or_staff`,
-- `shgs_update_leader_or_staff`, the `shg_join_requests` leader branch,
-- meeting-management policies, ...) keys purely off `current_role() =
-- 'leader' and current_shg_id() = S` — there is no separate "who was
-- actually appointed leader" concept anywhere in the schema — so this one
-- self-PATCH instantly grants full, unilateral leader authority (approve/
-- disburse OTHER members' loans, edit the SHG's profile, approve future
-- join requests into the same group) over an SHG she was never given any
-- real authority over.
--
-- Path B — pre-declare, then get an ordinary approval to walk it in. Even
-- WITHOUT path A, `RoleSelectPage` legitimately offers 'leader' as an
-- initial choice to any brand-new signup in live mode (`role_select_page.
-- dart`'s `selectableRoles`), and 0022's INSERT fix explicitly allows
-- `role in ('member', 'leader')` at first insert (with `shg_id` forced
-- null) — both by original design, matching 0009/0022's own comments
-- calling member/leader "genuinely self-service". So a brand-new user can
-- legally sign up with `role = 'leader'`, `shg_id = null`, then submit an
-- ORDINARY `shg_join_requests` request to any existing (already-led) SHG —
-- `shg_join_requests_insert_self` only checks `member_id = auth.uid()`,
-- with no role gate at all. `shg_join_requests_page.dart`'s Approve screen
-- (the real leader's own queue) shows only the requester's name and
-- request date — nothing about their self-declared role — so the real
-- leader has no way to notice anything unusual before tapping Approve on
-- what looks like an ordinary membership request. `approve_shg_join_
-- request()` (0004, `security definer`, bypasses RLS entirely, so 0009's
-- policy never even runs) does
-- `update public.profiles set shg_id = v_request.shg_id where id =
-- v_request.member_id` — it never touches or re-validates `role`. The
-- requester's `role` stays 'leader' from her own earlier self-declaration,
-- so after this completely ordinary-looking approval she is now a second,
-- fully-privileged, self-installed leader of a group she has no real claim
-- to — via two individually "legal" steps (an allowed insert, then an
-- ordinary approval by someone else), neither of which is a direct
-- escalation on its own, and neither of which 0009's single-statement
-- `with check` can see coming.
--
-- Fix (defense in depth — closes both paths independently):
--   (a) profiles_update_self_or_admin: a non-admin self-update may only
--       move `role` between 'member' and 'leader' while `shg_id` is (and
--       stays) null — i.e. only during onboarding, before any real SHG
--       linkage exists. Once a profile carries a non-null `shg_id`, `role`
--       is frozen for self-service; only an admin can change it from then
--       on (matching 0009's own comment: real promotions are meant to go
--       through "role promotions via Admin -> Users").
--   (b) approve_shg_join_request(): explicitly resets the approved
--       member's `role` back to 'member' as part of the SAME security-
--       definer update that sets `shg_id`, but ONLY when it currently
--       reads 'leader' — a self-declared value this flow was never meant
--       to grant real authority to. Staff roles (crp/clf/admin) are left
--       untouched if a staff account somehow ends up in this queue (no
--       real UI path does this, but there is no INSERT-side role gate on
--       `shg_join_requests` either, so it costs nothing to not clobber
--       staff). This flow is, and has only ever been, a self-service
--       MEMBER onboarding path (spec: "Member -> Select SHG -> Approval by
--       Leader"); real leader appointment is a separate, admin-driven
--       action and was never meant to be obtainable by walking through
--       this queue.

drop policy if exists "profiles_update_self_or_admin" on public.profiles;

create policy "profiles_update_self_or_admin" on public.profiles
  for update using (id = auth.uid() or public.current_role() = 'admin')
  with check (
    public.current_role() = 'admin'
    or (
      id = auth.uid()
      and shg_id is not distinct from public.current_shg_id()
      and (
        role = public.current_role()
        or (role in ('member', 'leader') and public.current_shg_id() is null)
      )
    )
  );

create or replace function public.approve_shg_join_request(p_request_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request record;
  v_member_role text;
begin
  select * into v_request from public.shg_join_requests where id = p_request_id;
  if v_request is null then
    raise exception 'join request not found';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'join request already decided';
  end if;

  if not (
    (public.current_role() = 'leader' and public.current_shg_id() = v_request.shg_id)
    or public.is_staff()
  ) then
    raise exception 'not authorized to decide this request';
  end if;

  if p_approve then
    select role into v_member_role from public.profiles where id = v_request.member_id;
    update public.profiles
      set shg_id = v_request.shg_id,
          role = case when v_member_role = 'leader' then 'member' else v_member_role end
      where id = v_request.member_id;
    update public.shg_join_requests set status = 'approved', decided_at = now(), decided_by = auth.uid() where id = p_request_id;
  else
    update public.shg_join_requests set status = 'rejected', decided_at = now(), decided_by = auth.uid() where id = p_request_id;
  end if;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 3. loans_update_leader_or_staff (0019) — re-derived against EVERY column
--    on `public.loans` (0001_init_schema.sql: id, shg_id, member_id,
--    purpose, amount, outstanding, emi, tenure_months, disbursed_on,
--    status, next_due_date, created_at), not just the self-approval shape
--    0013/0019 were written to close.
-- ─────────────────────────────────────────────────────────────────────────
-- 0019's `with check` locks `shg_id` (must stay the leader's own) and
-- `member_id` (must stay the loan's original borrower, and that borrower
-- must not be the leader herself) — correctly closing the self-approval
-- bug. But `amount`, `purpose`, `tenure_months`, and `created_at` are never
-- referenced at all. `LoanRepository` confirms no legitimate flow EVER
-- rewrites any of these four after `apply()` creates the row (`approve()`
-- only ever sends `status`/`disbursed_on`/`emi`/`next_due_date`; `reject()`
-- only `status`; `recordPayment()`'s fallback path only `outstanding`/
-- `status`) — so unlike `outstanding`/`emi`/`disbursed_on`/`next_due_date`
-- (deliberately left open below: real approval/payment flows legitimately
-- rewrite these, same as `status`), these four have zero legitimate write
-- use case, ever. Concretely: a leader approving (or rejecting) a fellow
-- MEMBER's loan (not her own — `member_id <> auth.uid()` still blocks
-- that) can, in the SAME `PATCH`, also send `{"status":"active",
-- "amount":999999,"purpose":"anything","tenure_months":1}` and it succeeds
-- today — silently rewriting another member's loan terms/purpose under
-- cover of an ordinary-looking approval, with no independent review of the
-- financial terms actually being approved. Fix: same security-definer
-- "read the row's current stored value, compare against it" pattern 0019
-- already established, extended to these four columns; read-gated to the
-- same scope `loans_select_shg_or_staff` already allows (own loan, own
-- SHG, or staff — matching 0020's read-gate fix for `loans_member_id`, so
-- this new function isn't a fresh cross-tenant read surface via direct
-- RPC).

create or replace function public.loans_locked_fields(p_loan_id uuid)
returns table (amount numeric, purpose text, tenure_months int, created_at timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select l.amount, l.purpose, l.tenure_months, l.created_at
  from public.loans l
  where l.id = p_loan_id
    and (l.member_id = auth.uid() or l.shg_id = public.current_shg_id() or public.is_staff());
$$;

revoke all on function public.loans_locked_fields(uuid) from public;
grant execute on function public.loans_locked_fields(uuid) to authenticated;

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
      and member_id = public.loans_member_id(loans.id)
      and public.loans_member_id(loans.id) <> auth.uid()
      and amount = (select f.amount from public.loans_locked_fields(loans.id) f)
      and purpose = (select f.purpose from public.loans_locked_fields(loans.id) f)
      and tenure_months = (select f.tenure_months from public.loans_locked_fields(loans.id) f)
      and created_at = (select f.created_at from public.loans_locked_fields(loans.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 4. marketplace_orders_update_seller_or_staff (0018) — re-derived against
--    EVERY column on `public.marketplace_orders` (0001_init_schema.sql +
--    the `buyer_id` column 0002 added: id, product_id, buyer_name, amount,
--    status, order_date, created_at, buyer_id).
-- ─────────────────────────────────────────────────────────────────────────
-- 0018 locks `product_id`, `buyer_id`, `buyer_name`, `amount`, `order_date`
-- (leaving only `status` freely writable, matching the one legitimate call
-- site, `MarketplaceRepository.updateOrderStatus()`). `id` turns out to
-- already be self-defending: trying to also rename the primary key in the
-- same update makes `marketplace_order_locked_fields(marketplace_orders.id)`
-- (evaluated against the NEW, not-yet-existing id) return no rows, so every
-- locked-field comparison becomes `= NULL` and the whole check fails —
-- verified by trace, not just assumed, so left as-is. `created_at` is the
-- one column actually missed: not referenced anywhere in 0018's `with
-- check`, so a seller can rewrite her own order's creation timestamp to
-- anything, in the same request as an otherwise-legitimate status update —
-- an audit-trail integrity gap (falsifying when an order was actually
-- placed, e.g. to manipulate time-based reporting or "recent orders"
-- ordering), same class of bug as the other four columns 0018 already
-- closed. Fix: add `created_at` to the locked-fields function/check (the
-- function's return-row shape is changing, so this needs `drop function`
-- first — `create or replace` can't add a column to an existing `returns
-- table` signature).

drop policy if exists "marketplace_orders_update_seller_or_staff" on public.marketplace_orders;
drop function if exists public.marketplace_order_locked_fields(uuid);

create function public.marketplace_order_locked_fields(p_order_id uuid)
returns table (product_id uuid, buyer_id uuid, buyer_name text, amount numeric, order_date timestamptz, created_at timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select o.product_id, o.buyer_id, o.buyer_name, o.amount, o.order_date, o.created_at
  from public.marketplace_orders o
  where o.id = p_order_id
    and (
      o.buyer_id = auth.uid()
      or exists (select 1 from public.marketplace_products p where p.id = o.product_id and p.seller_id = auth.uid())
      or public.is_staff()
    );
$$;

revoke all on function public.marketplace_order_locked_fields(uuid) from public;
grant execute on function public.marketplace_order_locked_fields(uuid) to authenticated;

create policy "marketplace_orders_update_seller_or_staff" on public.marketplace_orders
  for update using (
    exists (select 1 from public.marketplace_products p where p.id = product_id and p.seller_id = auth.uid())
    or public.is_staff()
  )
  with check (
    public.is_staff()
    or (
      exists (select 1 from public.marketplace_products p where p.id = product_id and p.seller_id = auth.uid())
      and product_id = (select l.product_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
      and buyer_id is not distinct from (select l.buyer_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
      and buyer_name = (select l.buyer_name from public.marketplace_order_locked_fields(marketplace_orders.id) l)
      and amount = (select l.amount from public.marketplace_order_locked_fields(marketplace_orders.id) l)
      and order_date = (select l.order_date from public.marketplace_order_locked_fields(marketplace_orders.id) l)
      and created_at = (select l.created_at from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    )
  );
