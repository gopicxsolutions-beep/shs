-- User-reported gap: the marketplace "Buy" flow had no quantity concept at
-- all — `product_detail_page.dart`'s Place Order button always bought
-- exactly 1 unit, with no way for a buyer to ask for more, forcing repeated
-- one-at-a-time orders for a bulk purchase. Not a UI oversight: `quantity`
-- didn't exist anywhere in this stack — not on `marketplace_orders`, not in
-- `place_marketplace_order` (migration 0057), not in the Dart model.
--
-- Adds `quantity` end to end, keeping migration 0057's atomicity guarantee
-- (stock check-and-decrement + order INSERT in one `security definer`
-- transaction, buyer identity server-derived) — this migration only widens
-- what that same transaction accounts for, it doesn't reopen the
-- price/stock-bypass gap 0057 closed.

alter table public.marketplace_orders
  add column quantity integer not null default 1
  check (quantity between 1 and 999); -- 999 is a plausibility cap, not a real business limit — matches this schema's existing convention for sanity-checking a client-supplied number (see e.g. loan amount, baseline-survey household size) rather than trusting stock alone to bound it.

comment on column public.marketplace_orders.quantity is
  'Units purchased in this order. amount is the TOTAL for all units (unit price x quantity at order time), not a per-unit price.';

-- Existing rows predate this column and are all genuinely single-unit
-- orders (there was no way to place any other kind) — the column default
-- already backfills them correctly; no data UPDATE needed.

drop function if exists public.place_marketplace_order(uuid);

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
begin
  if p_quantity is null or p_quantity < 1 or p_quantity > 999 then
    raise exception 'Quantity must be between 1 and 999.';
  end if;

  select name into v_buyer_name from public.profiles where id = auth.uid();
  if v_buyer_name is null then
    raise exception 'No profile found for the current user.';
  end if;

  -- `stock >= p_quantity`, not `stock > 0` — the exact same atomic
  -- check-and-decrement shape 0057 used for the single-unit case, now
  -- correctly refusing a partial fulfillment (e.g. 5 requested, 3 left)
  -- rather than silently selling fewer than asked for.
  update public.marketplace_products
  set stock = stock - p_quantity
  where id = p_product_id and stock >= p_quantity
  returning marketplace_products.price into v_price;

  get diagnostics v_row_count = row_count;

  -- Still report the real current unit price even when insufficient stock
  -- (0 rows updated) — matches 0057's own established shape, so the caller
  -- never has to trust a possibly-stale value even for the "not enough
  -- stock" case.
  if v_row_count = 0 then
    select p.price into v_price from public.marketplace_products p where p.id = p_product_id;
    return query select false, v_price, null::uuid;
    return;
  end if;

  insert into public.marketplace_orders (product_id, buyer_name, buyer_id, amount, quantity, status)
  values (p_product_id, v_buyer_name, auth.uid(), v_price * p_quantity, p_quantity, 'new')
  returning id into v_order_id;

  -- `price` in the return row is still the per-UNIT price (unchanged
  -- meaning from 0057) — the order's own `amount` column is the total.
  return query select true, v_price, v_order_id;
end;
$$;

revoke all on function public.place_marketplace_order(uuid, integer) from public;
grant execute on function public.place_marketplace_order(uuid, integer) to authenticated;
