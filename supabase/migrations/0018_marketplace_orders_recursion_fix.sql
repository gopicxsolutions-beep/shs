-- CRITICAL, LIVE-VERIFIED REGRESSION FIX. Round 13's `with check` on
-- `marketplace_orders_update_seller_or_staff` (0013_self_service_write_check_gaps.sql)
-- was written with a self-referencing subquery — comparing the row's new
-- values against its own stored values via
-- `(select o.product_id from public.marketplace_orders o where o.id = marketplace_orders.id)`
-- — to lock every column except `status` during a seller's status update.
-- That subquery selects FROM the same table the policy is defined ON,
-- which is subject to RLS itself, which re-triggers evaluation of this
-- SAME policy on the SAME row — a genuine, well-documented PostgreSQL RLS
-- gotcha, not something the earlier round's careful reasoning about
-- "does this break any existing feature" checklist could have caught,
-- since it's a query-planning/evaluation-order failure, not a logic bug.
--
-- Found live, this session, via `/loop`'s strict live-mode-only testing
-- rule: attempting the legitimate, exact intended use case (a seller
-- updating her own order's status through the real app UI) failed with a
-- generic "Could not update the order status" error. Reproduced directly
-- against the REST API to get the real underlying error:
--   {"code":"42P17","message":"infinite recursion detected in policy for
--   relation \"marketplace_orders\""}
-- This is NOT a narrow edge case — it broke the ONE legitimate write path
-- this policy exists to support, for every seller, on every order, all
-- the time, with a hard 500 error. A more severe production regression
-- than the self-service-column-spoofing gap round 13 was closing (a
-- theoretical, direct-REST-only exploit) — this took down a real,
-- actively-used feature (order fulfillment tracking) outright.
--
-- Fix: the exact pattern this session already established for exactly
-- this class of problem (0013/0017's `profile_shg_id()`/`shgs_current_row()`)
-- — move the self-referencing read into a `security definer` function.
-- A security-definer function runs as its owner (which bypasses RLS on
-- its OWN internal query, since RLS doesn't apply to a table's owning
-- role by default), so the read no longer re-enters the policy being
-- evaluated — breaking the recursion cleanly while keeping the exact same
-- "every other column must stay byte-for-byte the same" guarantee.

create or replace function public.marketplace_order_locked_fields(p_order_id uuid)
returns table (product_id uuid, buyer_id uuid, buyer_name text, amount numeric, order_date timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select o.product_id, o.buyer_id, o.buyer_name, o.amount, o.order_date
  from public.marketplace_orders o
  where o.id = p_order_id;
$$;

revoke all on function public.marketplace_order_locked_fields(uuid) from public;
grant execute on function public.marketplace_order_locked_fields(uuid) to authenticated;

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
      -- `IS NOT DISTINCT FROM` doesn't support a multi-column subquery as
      -- its right-hand side the way `=` does (confirmed live: Postgres
      -- rejects it with "subquery must return only one column") — each
      -- locked field is compared individually instead, same as the
      -- original (recursive) policy did, just sourced from the
      -- security-definer function above instead of a raw self-join.
      and product_id = (select l.product_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
      and buyer_id is not distinct from (select l.buyer_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
      and buyer_name = (select l.buyer_name from public.marketplace_order_locked_fields(marketplace_orders.id) l)
      and amount = (select l.amount from public.marketplace_order_locked_fields(marketplace_orders.id) l)
      and order_date = (select l.order_date from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    )
  );
