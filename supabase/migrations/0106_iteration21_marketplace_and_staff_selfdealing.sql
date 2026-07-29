-- Gap-hunt iteration 21 (round 194): 4 parallel audits (dogfood round 193,
-- Marketplace full sweep, Training/Certificates + Schemes, Payments +
-- Financial Ledger UI) — this migration closes every RLS/backend gap found.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [HIGH] `marketplace_orders_insert_staff` had ZERO field-level
--    restriction (`with check (is_staff())`) — any crp/clf/admin could
--    directly insert a fabricated order for any product, as any buyer,
--    with any status (including 'delivered'), bypassing `place_marketplace_
--    order` entirely and stock never touched. Live-verified this round: a
--    forged 'delivered' order was then used to pass `marketplace_reviews_
--    insert_authenticated`'s "must have a delivered order" check, posting
--    a fake "verified purchase" 5-star review for a product never bought.
--    No UI call site anywhere in `lib/` uses this policy (confirmed by
--    grep) — staff has no legitimate reason to directly insert an order
--    row (a phone/in-person order should still go through the same
--    validated path everyone else uses). Retiring the policy entirely
--    rather than trying to patch it, matching this session's established
--    preference for removing unused permissive grants over leaving
--    exploitable surface area for a feature that doesn't exist.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "marketplace_orders_insert_staff" on public.marketplace_orders;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. [HIGH] The one-step order-status transition guard (`advance_
--    marketplace_order_status`, migration 0068 — sellers can only move
--    new→packed→shipped→delivered one step at a time, forward or back)
--    was only ever enforced inside that RPC, never in `marketplace_orders_
--    update_seller_or_staff`'s own WITH CHECK. Per this project's own
--    security model ("RLS in Postgres is authorization, client-side/RPC-
--    only checks are not"), a seller could call a plain `UPDATE ...
--    SET status = 'delivered'` directly against the table — bypassing the
--    RPC and the one-step guard entirely — live-verified to succeed this
--    round. Folding the guard into the policy itself closes the real
--    boundary; the RPC remains the app's own call path (still race-guarded
--    via its `FOR UPDATE` lock) but is no longer the only thing enforcing
--    the rule. Staff remains unrestricted, matching the RPC's own
--    `if not is_staff() then <check> end if` shape.
--
--    Requires `marketplace_order_locked_fields` to also expose the OLD
--    `status` value (previously omitted since status was the one
--    intentionally-unlocked column) — the column list changes, so the
--    function is dropped and recreated rather than replaced in place.
-- ─────────────────────────────────────────────────────────────────────────

-- Must drop the dependent policy before the function it references.
drop policy if exists "marketplace_orders_update_seller_or_staff" on public.marketplace_orders;
drop function if exists public.marketplace_order_locked_fields(uuid);

create function public.marketplace_order_locked_fields(p_order_id uuid)
returns table (product_id uuid, buyer_id uuid, buyer_name text, amount numeric, order_date timestamptz, created_at timestamptz, status text)
language sql
stable security definer
set search_path = public
as $$
  select o.product_id, o.buyer_id, o.buyer_name, o.amount, o.order_date, o.created_at, o.status
  from public.marketplace_orders o
  where o.id = p_order_id
    and (
      o.buyer_id = auth.uid()
      or exists (select 1 from public.marketplace_products p where p.id = o.product_id and p.seller_id = auth.uid())
      or public.is_staff()
    );
$$;

revoke all on function public.marketplace_order_locked_fields(uuid) from public, anon;
grant execute on function public.marketplace_order_locked_fields(uuid) to authenticated;

create policy "marketplace_orders_update_seller_or_staff" on public.marketplace_orders
  for update using (
    (exists (select 1 from public.marketplace_products p where p.id = marketplace_orders.product_id and p.seller_id = auth.uid() and public.profile_is_active(p.seller_id)))
    or public.is_staff()
  )
  with check (
    (
      public.is_staff()
      or (
        (exists (select 1 from public.marketplace_products p where p.id = marketplace_orders.product_id and p.seller_id = auth.uid() and public.profile_is_active(p.seller_id)))
        and abs(
          array_position(array['new','packed','shipped','delivered'], status)
          - array_position(array['new','packed','shipped','delivered'], (select l.status from public.marketplace_order_locked_fields(marketplace_orders.id) l))
        ) = 1
      )
    )
    and product_id = (select l.product_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and buyer_id is not distinct from (select l.buyer_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and buyer_name = (select l.buyer_name from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and amount = (select l.amount from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and order_date = (select l.order_date from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and created_at = (select l.created_at from public.marketplace_order_locked_fields(marketplace_orders.id) l)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3 & 4. [LOW, grant hygiene] `advance_marketplace_order_status` and
--    `decide_scheme_application` both missed the anon-grant-hygiene sweeps
--    (migrations 0096-0098) — this project's `public` schema grants EXECUTE
--    on every newly-created function directly to `anon` by default, and a
--    bare `revoke all ... from public` never touches that. Both confirmed
--    non-exploitable today (each fails closed on its first internal
--    `is_staff()`/`profile_is_active()` call before any business logic
--    runs), but closing them for consistency and defense-in-depth, per the
--    same standing rule this session has applied ~30 times already.
-- ─────────────────────────────────────────────────────────────────────────

revoke execute on function public.advance_marketplace_order_status(uuid, text) from anon;
revoke execute on function public.decide_scheme_application(uuid, boolean) from anon;

-- ─────────────────────────────────────────────────────────────────────────
-- 5. [HIGH] `course_progress_write_self_or_staff`'s staff branch
--    (`is_staff() and profile_is_active(member_id)`) had no self-exclusion
--    — the exact "no identity may escalate itself" bug already fixed for
--    the sibling `scheme_applications_update_staff` policy (migration
--    0049), but never applied here. Live-verified: a CRP account could
--    directly upsert her OWN `course_progress` row with `certified=true`,
--    bypassing `submit_quiz_attempt` (the app's only intended
--    certification path, per docs/SRS.md FR-TRN-3) entirely — no quiz ever
--    answered. No legitimate feature needs staff to mark HER OWN training
--    complete via the staff bypass; self-certification (if earned) already
--    goes through the identical `member_id = auth.uid()` branch every
--    other role uses.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "course_progress_write_self_or_staff" on public.course_progress;

create policy "course_progress_write_self_or_staff" on public.course_progress
  for all using (member_id = auth.uid() or public.is_staff())
  with check (
    (public.is_staff() and profile_is_active(member_id) and member_id <> auth.uid())
    or (
      member_id = auth.uid()
      and profile_is_active(member_id)
      and certified = coalesce((select f.certified from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f), false)
      and completed_on is not distinct from (select f.completed_on from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 6. [MEDIUM] `financial_ledger_delete_staff` (self-excluded in migration
--    0104/0105) still let any staff account delete a MID-SEQUENCE row
--    belonging to a DIFFERENT staff/leader — `balance` is a stored value
--    computed once at insert time from the previous row via
--    `financial_ledger_previous_balance()`, not recomputed on read, so
--    deleting row N leaves row N+1's balance silently referencing a chain
--    that no longer exists, with no tombstone or recomputation. Live-
--    verified: seeding 3 chained entries and deleting the middle one
--    succeeds today with no error, corrupting the audit trail. Restricting
--    DELETE to only the most-recent row per `(shg_id, entry_type)` closes
--    this — a correction is still possible (delete the latest entry, then
--    re-add it correctly), just not a silent gap in the middle of the
--    chain.
--
--    The "is this the latest row in its group" check is wrapped in a
--    SECURITY DEFINER function rather than an inline subquery directly in
--    the policy — matching this schema's established pattern (every
--    `*_locked_fields` helper, `current_shg_id()`, etc.) for a table's own
--    RLS policy needing to read other rows of that same table, since a
--    raw self-referencing subquery inline in a policy risks the 42P17
--    infinite-recursion class this project has hit before (see
--    docs/ARCHITECTURE.md's RLS helper-functions section).
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.financial_ledger_is_latest(p_id uuid)
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select not exists (
    select 1 from public.financial_ledger newer
    join public.financial_ledger this_row on this_row.id = p_id
    where newer.shg_id = this_row.shg_id
      and newer.entry_type = this_row.entry_type
      and newer.created_at > this_row.created_at
  );
$$;

revoke all on function public.financial_ledger_is_latest(uuid) from public, anon;
grant execute on function public.financial_ledger_is_latest(uuid) to authenticated;

drop policy if exists "financial_ledger_delete_staff" on public.financial_ledger;

create policy "financial_ledger_delete_staff" on public.financial_ledger
  for delete using (
    public.is_staff()
    and created_by <> auth.uid()
    and public.financial_ledger_is_latest(id)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 7. [LOW, defense-in-depth] `marketplace_reviews_moderate_staff`/`_delete_
--    staff`'s self-exclusion used `reviewer_id <> auth.uid()` — NULL-unsafe
--    against `reviewer_id`, which is nullable in the schema (unlike every
--    other owner column this class of fix has touched). A row with a NULL
--    reviewer_id would make `<> auth.uid()` evaluate to NULL (falsy),
--    silently blocking staff from ever moderating/deleting it. Confirmed
--    currently unreachable in practice (a pre-existing trigger makes a
--    NULL reviewer_id row impossible to insert at all — `reviewer_name`
--    would fail its own NOT NULL constraint first), but switching to
--    `IS DISTINCT FROM` matches the null-safe pattern already used
--    correctly elsewhere in this same migration family, for defense in
--    depth against a future schema change.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "marketplace_reviews_moderate_staff" on public.marketplace_reviews;

create policy "marketplace_reviews_moderate_staff" on public.marketplace_reviews
  for update using (public.is_staff() and reviewer_id is distinct from auth.uid())
  with check (
    public.is_staff()
    and reviewer_id is distinct from auth.uid()
    and product_id = (select f.product_id from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
    and reviewer_id is not distinct from (select f.reviewer_id from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
    and reviewer_name = (select f.reviewer_name from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
    and created_at = (select f.created_at from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
  );

drop policy if exists "marketplace_reviews_delete_staff" on public.marketplace_reviews;
create policy "marketplace_reviews_delete_staff" on public.marketplace_reviews
  for delete using (public.is_staff() and reviewer_id is distinct from auth.uid());
