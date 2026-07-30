-- Gap-hunt iteration 38: a fresh Marketplace browse/search audit found
-- `marketplace_products_select_all`/`marketplace_reviews_select_all` had
-- no `profile_is_active(seller_id)` check at all — unlike the UPDATE
-- policy on the same table, which already gates on it
-- (`marketplace_products_update_seller_or_staff`). A deactivated seller's
-- listings stayed fully visible/browsable on the catalog and product
-- detail page with a normal-looking "Place order" button; only
-- `place_marketplace_order()`'s own check actually blocked the purchase,
-- and `product_detail_page.dart`'s generic catch-all error swallowed the
-- reason. Net effect: stale/dead catalog entries were indistinguishable
-- from live ones until a buyer tried to purchase and was silently
-- rejected. Fixed by hiding a deactivated seller's products/reviews from
-- the general catalog — staff retain full visibility for
-- moderation/audit, matching every other staff-oversight policy in this
-- schema.
drop policy if exists "marketplace_products_select_all" on public.marketplace_products;
create policy "marketplace_products_select_all" on public.marketplace_products
  for select using (public.profile_is_active(seller_id) or public.is_staff());

drop policy if exists "marketplace_reviews_select_all" on public.marketplace_reviews;
create policy "marketplace_reviews_select_all" on public.marketplace_reviews
  for select using (
    public.is_staff()
    or exists (
      select 1 from public.marketplace_products p
      where p.id = marketplace_reviews.product_id and public.profile_is_active(p.seller_id)
    )
  );
