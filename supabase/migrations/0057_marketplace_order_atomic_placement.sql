-- Closes two real, live-confirmed gaps in the Marketplace "Buy" flow that
-- migration 0008 partially addressed and 0027 explicitly disclosed but left
-- open ("amount is still not tied to marketplace_products.price by any
-- `with check` -- only the app's own decrement_product_stock RPC-then-
-- insert convention keeps it honest in practice, never RLS itself").
--
-- 0027's own reasoning for not fixing it at the time was sound as far as it
-- went: a hard `amount = (select price ...)` WITH CHECK would race a
-- legitimate concurrent seller price edit, since the RPC call and the order
-- INSERT are two separate round trips from the Dart client with no shared
-- transaction. But the fix that reasoning was weighing wasn't the only
-- option -- making the RPC itself perform the INSERT (one atomic
-- transaction, no client-visible gap between price-verification and
-- order-creation at all) sidesteps the race entirely rather than trying to
-- out-race it with a check. This is exactly the pattern this schema already
-- uses for `add_financial_ledger_entry` (0011) and `record_loan_payment` --
-- `decrement_product_stock` (0008) was the outlier that verified a value
-- and handed it back to the client to use honestly, instead of using it
-- itself.
--
-- Both gaps live-confirmed this round (round 125), not just re-derived from
-- reading the policy text:
--
-- 1. Price/stock-bypass fraud: `marketplace_orders_insert_authenticated`'s
--    WITH CHECK locks buyer_id/status/order_date/created_at but never
--    `amount` -- a direct `POST /rest/v1/marketplace_orders` (skipping
--    decrement_product_stock entirely) let a synthetic plain-member test
--    account create a real order row for a real ₹5,000 test product at
--    `amount: 1`, with the product's stock ('__TEST__ Product',
--    3 -> still 3 afterward) never touched at all -- a buyer could
--    fabricate an arbitrarily-cheap paper trail for a real product with no
--    server-side relationship to its actual price whatsoever.
--
-- 2. Stock-griefing DoS, independent of gap 1 and pre-dating it back to
--    0008 itself: `decrement_product_stock` is `security definer` and
--    freestanding -- ANY authenticated user could call it directly against
--    ANY product, with no accompanying order, no purchase intent, and no
--    trace. Live-confirmed: calling it directly against the same test
--    product as the synthetic test buyer (who has no relationship to that
--    product at all) silently took its stock from 3 to 2 with zero orders
--    created. Repeated calls let any authenticated user zero out any
--    seller's stock at will -- a targeted denial-of-service against any
--    seller on the platform, not just a pricing-integrity issue.
--
-- Fix: replace decrement_product_stock with place_marketplace_order, which
-- does the entire purchase -- stock check-and-decrement, price lookup,
-- buyer identity, and the order INSERT itself -- inside one security
-- definer transaction. buyer_id/buyer_name are derived server-side from
-- auth.uid()/profiles.name rather than accepted as client-supplied
-- parameters at all (profiles.name is exactly what AppUser.name already
-- resolves to for the current session -- see app_state.dart's `AppUser
-- (name: _profile!.name, ...)` -- so this changes nothing for the app's own
-- always-logged-in-buyer flow while closing the same spoofing shape for a
-- direct-REST caller that gap 1 had for `amount`).
create or replace function public.place_marketplace_order(p_product_id uuid)
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
  select name into v_buyer_name from public.profiles where id = auth.uid();
  if v_buyer_name is null then
    raise exception 'No profile found for the current user.';
  end if;

  update public.marketplace_products
  set stock = stock - 1
  where id = p_product_id and stock > 0
  returning marketplace_products.price into v_price;

  get diagnostics v_row_count = row_count;

  -- Still report the real current price even when out of stock (0 rows
  -- updated), matching decrement_product_stock's own established shape --
  -- the caller never has to trust its own possibly-stale value even for
  -- the "sold out" case.
  if v_row_count = 0 then
    select p.price into v_price from public.marketplace_products p where p.id = p_product_id;
    return query select false, v_price, null::uuid;
    return;
  end if;

  insert into public.marketplace_orders (product_id, buyer_name, buyer_id, amount, status)
  values (p_product_id, v_buyer_name, auth.uid(), v_price, 'new')
  returning id into v_order_id;

  return query select true, v_price, v_order_id;
end;
$$;

revoke all on function public.place_marketplace_order(uuid) from public;
grant execute on function public.place_marketplace_order(uuid) to authenticated;

-- decrement_product_stock is now fully superseded and was independently
-- exploitable on its own terms (gap 2 above) -- drop entirely rather than
-- just revoking, since MarketplaceRepository was grep-confirmed as its only
-- caller and is switched to place_marketplace_order in the same app change
-- as this migration.
drop function if exists public.decrement_product_stock(uuid);

-- Ordinary buyers now go exclusively through place_marketplace_order()'s
-- security-definer INSERT, which bypasses this table's own RLS entirely
-- (as every security-definer write in this schema does) regardless of what
-- policy exists here -- so removing the "any authenticated" branch only
-- closes the DIRECT-insert path (gap 1's actual exploit surface) without
-- affecting the function's own ability to write. is_staff() kept for
-- administrative flexibility, matching every other table's established
-- staff-can-always-write shape, even though no current UI exercises a
-- staff-direct-insert path here.
drop policy if exists "marketplace_orders_insert_authenticated" on public.marketplace_orders;

create policy "marketplace_orders_insert_staff" on public.marketplace_orders
  for insert with check (is_staff());
