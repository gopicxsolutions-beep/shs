-- Marketplace + Payments batch audit — independently re-verified 0018's
-- recursion fix is correct (traced the exact seller-updates-order-status
-- scenario step by step: the app only ever sends `{"status": <new>}`
-- (`MarketplaceRepository.updateOrderStatus`, marketplace_repository.dart),
-- so every OTHER column keeps its existing stored value after a Postgrest
-- partial update; `marketplace_order_locked_fields(id)` — a `security
-- definer` function whose internal query bypasses RLS since `force row
-- level security` is OFF for every table in this schema (confirmed by
-- 0002's own header comment, the same fact round 39 already leaned on) —
-- reads that pre-update stored value without re-entering the very policy
-- being evaluated, breaking the recursion while keeping the "every column
-- except `status` must stay byte-for-byte identical" guarantee intact.
-- This matches round 36's own live three-way verification and is now
-- independently confirmed correct by static trace too). Also swept every
-- other marketplace/payments RLS policy (`marketplace_products_*`,
-- `marketplace_reviews_*`, `payments_*`) for the same self-referencing-
-- subquery shape: none of them have it — `marketplace_orders_update_
-- seller_or_staff` (fixed in 0018) was the only instance in this domain,
-- consistent with round 37/39's conclusion that `marketplace_orders` and
-- `loans` were the only two tables with this anti-pattern anywhere in the
-- schema.
--
-- One NEW gap found while re-verifying 0018, structurally identical to the
-- one round 39 found and fixed for `loans_member_id` in
-- 0020_loans_member_id_read_gate.sql (itself modeled on 0017's
-- `shgs_current_row` hardening): `marketplace_order_locked_fields(p_order_id
-- uuid)` (0018) is `security definer` with NO caller-authorization check of
-- its own. It was written purely as a "read this order's current stored
-- columns" helper, correct for its one real call site (this policy's own
-- `with check`, only ever invoked with an order id the caller already has
-- `using`-clause-level access to — i.e. already proven to be the order's
-- seller or staff). But 0018 also granted `execute` on it broadly to
-- `authenticated`, and it is directly callable as a REST RPC
-- (`POST /rest/v1/rpc/marketplace_order_locked_fields`) by ANY
-- authenticated user with ANY order id — returning that order's
-- `product_id`/`buyer_id`/`buyer_name`/`amount`/`order_date` with zero
-- regard for `marketplace_orders_select_related` (buyer, seller, or staff
-- only). A member with no connection to a given order — not its buyer, not
-- its seller — could learn who bought what, for how much, and when, for
-- any order anywhere in the marketplace, bypassing the same buyer/seller
-- confidentiality boundary this schema otherwise enforces everywhere else
-- for order data. Grepped `lib/` and confirmed this function is never
-- called from Dart (RLS-internal only) — same as `loans_member_id`, a
-- REST-only surface, not reachable through the app's own UI, but a real
-- trust-boundary gap per this schema's own established standard.
--
-- Fix: identical to 0020's fix for the same shape — gate the function's own
-- query to the same scope `marketplace_orders_select_related` already
-- allows (buyer, the order's product's seller, or staff). A no-op for the
-- real call site (`marketplace_orders_update_seller_or_staff`'s `with
-- check`, which only ever calls this with an order id the caller already
-- passed the `using` clause for — seller or staff, both included below),
-- closing the direct-RPC cross-buyer/cross-seller read gap.

create or replace function public.marketplace_order_locked_fields(p_order_id uuid)
returns table (product_id uuid, buyer_id uuid, buyer_name text, amount numeric, order_date timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select o.product_id, o.buyer_id, o.buyer_name, o.amount, o.order_date
  from public.marketplace_orders o
  where o.id = p_order_id
    and (
      o.buyer_id = auth.uid()
      or exists (select 1 from public.marketplace_products p where p.id = o.product_id and p.seller_id = auth.uid())
      or public.is_staff()
    );
$$;
