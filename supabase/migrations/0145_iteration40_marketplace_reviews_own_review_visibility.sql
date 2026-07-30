-- Gap-hunt iteration 40 dogfooding: 0142's deactivated-seller hiding was
-- also never carried over to `marketplace_reviews_select_all`, which
-- joins the same `profile_is_active(seller_id)` condition through
-- `marketplace_products` with no analogous "this is my own review"
-- exception. Live-verified: a buyer with a real order AND a real review
-- for a deactivated seller's product could (correctly, per 0143/0144) see
-- the product again, but her own review of it stayed invisible — the
-- exact same "historical record shouldn't change because of an unrelated
-- later account-status change" problem 0143 fixed for orders, left open
-- for reviews. Fixed directly on `reviewer_id`, no extra join needed
-- (unlike products/orders, a review row already carries its own author).
drop policy if exists "marketplace_reviews_select_all" on public.marketplace_reviews;
create policy "marketplace_reviews_select_all" on public.marketplace_reviews
  for select using (
    is_staff()
    or reviewer_id = auth.uid()
    or exists (
      select 1 from public.marketplace_products p
      where p.id = marketplace_reviews.product_id and profile_is_active(p.seller_id)
    )
  );
