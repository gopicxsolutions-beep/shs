-- Fixes two real, live-discovered bugs in the Marketplace "Buy" flow:
--
-- 1. `marketplace_products_write_seller_or_staff` (0002_rls_policies.sql)
--    restricts UPDATE on marketplace_products to the seller or staff, but
--    MarketplaceRepository.placeOrder() has always decremented stock via a
--    direct client-side UPDATE issued *as the buyer* — under RLS this has
--    always silently affected 0 rows for any real buyer (i.e. anyone other
--    than the product's own seller), so stock has never actually
--    decremented for a genuine purchase. The order insert itself has its
--    own separate, correctly-scoped RLS policy and so has always still
--    succeeded — the bug is invisible unless you specifically check
--    whether stock changed. Separately, even ignoring the RLS gap, the old
--    client-side "select stock, then update stock - 1" pattern is not
--    atomic: two buyers racing for the last unit could both read stock > 0
--    and both successfully decrement, overselling.
--
-- 2. `marketplace_orders.amount` was always whatever the CLIENT supplied
--    (`product.price` read earlier into the Flutter widget tree, with no
--    server-side re-validation against the product's actual current
--    price at order time) — a legitimate trust-boundary gap: a stale page
--    (seller changed the price after the buyer's page loaded) or a
--    modified client could record any amount at all for a real order.
--
-- Fix: a narrowly-scoped `security definer` RPC that does exactly two
-- things atomically — decrements a product's stock by exactly 1 only if
-- stock is currently > 0, and returns the product's *actual, current*
-- price read server-side in the same statement — bypassing the
-- seller-only RLS boundary just enough for this one safe operation,
-- callable by any authenticated buyer. The caller uses the returned price
-- for the order it inserts immediately after, instead of trusting its own
-- (potentially stale or tampered) value.

create or replace function public.decrement_product_stock(p_product_id uuid)
returns table (success boolean, price numeric)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row_count integer;
  v_price numeric;
begin
  update public.marketplace_products
  set stock = stock - 1
  where id = p_product_id and stock > 0
  returning marketplace_products.price into v_price;

  get diagnostics v_row_count = row_count;

  -- Still report the real current price even when out of stock (0 rows
  -- updated), so the caller never has to trust its own possibly-stale
  -- value even for the "sold out" case.
  if v_row_count = 0 then
    select p.price into v_price from public.marketplace_products p where p.id = p_product_id;
  end if;

  return query select (v_row_count > 0), v_price;
end;
$$;

revoke all on function public.decrement_product_stock(uuid) from public;
grant execute on function public.decrement_product_stock(uuid) to authenticated;
