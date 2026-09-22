-- CRITICAL, self-caused regression — found the same day it shipped, via a
-- dedicated re-audit of the marketplace module after adding quantity
-- support. 0153 rewrote `place_marketplace_order` starting from the
-- migration-0057 definition (the one this repo's own doc comments/tests
-- happened to have most readily at hand) instead of the LIVE current one —
-- four intermediate migrations (0091, 0098, 0111, 0131) had each hardened
-- this exact function since 0057, and every one of those five checks was
-- silently dropped by 0153's `drop function ...; create or replace
-- function ...` with a new signature:
--
--   1. `profile_is_active(auth.uid())` — 0131: a staff-deactivated BUYER's
--      still-valid session could keep placing orders.
--   2. 20-orders/hour per-buyer rate limit — 0131: reopens the exact
--      unlimited stock-draining DoS that migration's own header describes
--      finding live ("a scripted caller drains every seller's stock to
--      zero at no cost").
--   3. `profile_is_active(v_seller_id)` — 0098/0111: a STAFF-deactivated
--      seller's products became purchasable again.
--   4. `v_seller_id = auth.uid()` self-order block — 0131: a seller could
--      order her own listing again (the same self-dealing shape 0048's
--      review fix and this schema's "no identity may escalate/self-deal"
--      convention exist to close everywhere else).
--   5. `is_active` check on the product itself — 0150, THE ENTIRE POINT OF
--      THAT MIGRATION: a delisted product became orderable again via a
--      direct RPC call, exactly the gap 0150 closed and documented.
--
-- Root-cause lesson for next time: before rewriting any `security definer`
-- function via `drop ...; create or replace ...`, grep every migration
-- touching that function name first (`grep -rl "function public.<name>"
-- supabase/migrations/`), not just the one migration that happens to be
-- cited in a nearby doc comment — a live `pg_get_functiondef` read against
-- the actual deployed function is the only fully reliable source of the
-- CURRENT definition, and should have been done here before touching it.
--
-- This migration restores all five guards on top of 0153's quantity
-- support (never reverted — quantity itself was correct and is kept), and
-- additionally closes two more real gaps a self-review of 0153 caught
-- before anyone exploited them:
--
--   6. `quantity` was added to `marketplace_orders` but never added to
--      `marketplace_order_locked_fields`/`marketplace_orders_update_
--      seller_or_staff`'s locked-column list (0106/0113) — a seller (or
--      staff) advancing an order's status in the same PATCH could silently
--      rewrite `quantity` to anything, leaving the buyer's own order
--      history showing a quantity that contradicts the (still-locked, so
--      unchanged) `amount` she was actually charged.
--   7. 0153's `revoke all on function ... from public;` omitted `, anon` —
--      every sibling migration in this schema revokes from both (`0150`,
--      `0131`, `0106`, and the dedicated `0096` grant-hygiene sweep, whose
--      header explains new functions get a default `anon` EXECUTE grant
--      that a bare `revoke ... from public` never touches). Fails closed
--      today only because `auth.uid()` is null for an anon caller; fixing
--      it anyway to match the schema's own standing convention.

drop function if exists public.place_marketplace_order(uuid, integer);

create or replace function public.place_marketplace_order(p_product_id uuid, p_quantity integer default 1)
returns table (success boolean, price numeric, order_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row_count integer;
  v_price numeric;
  v_buyer_name text;
  v_order_id uuid;
  v_seller_id uuid;
  v_recent_orders integer;
begin
  if p_quantity is null or p_quantity < 1 or p_quantity > 999 then
    raise exception 'Quantity must be between 1 and 999.';
  end if;

  select name into v_buyer_name from public.profiles where id = auth.uid();
  if v_buyer_name is null then
    raise exception 'No profile found for the current user.';
  end if;
  if not public.profile_is_active(auth.uid()) then
    raise exception 'your account has been deactivated';
  end if;

  select count(*) into v_recent_orders
  from public.marketplace_orders
  where buyer_id = auth.uid() and created_at > now() - interval '1 hour';
  if v_recent_orders >= 20 then
    raise exception 'too many orders placed in the last hour';
  end if;

  select seller_id into v_seller_id from public.marketplace_products where id = p_product_id;
  if v_seller_id is not null and not public.profile_is_active(v_seller_id) then
    raise exception 'this product is no longer available';
  end if;
  if v_seller_id = auth.uid() then
    raise exception 'you cannot order your own product';
  end if;
  if not exists (select 1 from public.marketplace_products where id = p_product_id and is_active) then
    raise exception 'this product is no longer available';
  end if;

  -- `stock >= p_quantity`, not `stock > 0` (0153's own change, kept): a
  -- request for more than remains is refused outright rather than
  -- partially fulfilled.
  update public.marketplace_products
  set stock = stock - p_quantity
  where id = p_product_id and stock >= p_quantity
  returning marketplace_products.price into v_price;

  get diagnostics v_row_count = row_count;

  if v_row_count = 0 then
    select p.price into v_price from public.marketplace_products p where p.id = p_product_id;
    return query select false, v_price, null::uuid;
    return;
  end if;

  insert into public.marketplace_orders (product_id, buyer_name, buyer_id, amount, quantity, status)
  values (p_product_id, v_buyer_name, auth.uid(), v_price * p_quantity, p_quantity, 'new')
  returning id into v_order_id;

  return query select true, v_price, v_order_id;
end;
$$;

revoke all on function public.place_marketplace_order(uuid, integer) from public, anon;
grant execute on function public.place_marketplace_order(uuid, integer) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- Lock `quantity` the same way every other order column already is.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "marketplace_orders_update_seller_or_staff" on public.marketplace_orders;
drop function if exists public.marketplace_order_locked_fields(uuid);

create function public.marketplace_order_locked_fields(p_order_id uuid)
returns table (product_id uuid, buyer_id uuid, buyer_name text, amount numeric, quantity integer, order_date timestamptz, created_at timestamptz, status text)
language sql
stable security definer
set search_path = public
as $$
  select o.product_id, o.buyer_id, o.buyer_name, o.amount, o.quantity, o.order_date, o.created_at, o.status
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
      (
        public.is_staff()
        and buyer_id is distinct from auth.uid()
        and not exists (select 1 from public.marketplace_products p where p.id = marketplace_orders.product_id and p.seller_id = auth.uid())
      )
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
    and quantity = (select l.quantity from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and order_date = (select l.order_date from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and created_at = (select l.created_at from public.marketplace_order_locked_fields(marketplace_orders.id) l)
  );
