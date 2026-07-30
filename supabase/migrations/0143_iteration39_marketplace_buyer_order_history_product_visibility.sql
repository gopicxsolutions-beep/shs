-- Gap-hunt iteration 39 dogfooding: migration 0142's own fix (hiding a
-- deactivated seller's products from the general catalog) had a real,
-- confirmed side effect on a DIFFERENT feature — a buyer's own past order
-- history. `marketplace_repository.dart`'s `fetchOrdersForBuyer`/
-- `fetchOrderById` embed `marketplace_products(name, seller_id)`, which is
-- the same RLS-gated table; once a seller is deactivated, that embed
-- silently resolves to null for every buyer who ever bought from her,
-- permanently degrading her own order history to a generic "Product"
-- placeholder with no seller — even though the order itself (and what was
-- actually purchased) is real, historical, and none of that should change
-- just because the seller's account status changed afterward.
--
-- Fixed narrowly: a buyer can still see the product row for an order she
-- actually placed, regardless of the seller's current active status.
-- General catalog browsing for a deactivated seller's products stays
-- exactly as closed as 0142 made it — this only widens visibility for the
-- one buyer who has a real, already-placed order referencing that product.
drop policy if exists "marketplace_products_select_all" on public.marketplace_products;
create policy "marketplace_products_select_all" on public.marketplace_products
  for select using (
    public.profile_is_active(seller_id)
    or public.is_staff()
    or exists (
      select 1 from public.marketplace_orders o
      where o.product_id = marketplace_products.id and o.buyer_id = auth.uid()
    )
  );
