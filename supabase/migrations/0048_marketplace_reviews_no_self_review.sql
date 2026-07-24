-- ─────────────────────────────────────────────────────────────────────────
-- marketplace_reviews_insert_authenticated: block a seller from reviewing
-- her own product
--
-- `0032_marketplace_reviews_authorship_and_dupes.sql` correctly requires an
-- identified reviewer to have a real order for the product being reviewed
-- (no fabricating a 5-star review with no purchase), but never checked
-- WHOSE product it is — nothing stopped a seller from placing an order
-- against her own listing (`marketplace_orders_insert_authenticated` has no
-- seller/buyer cross-check either) and then reviewing it herself, using
-- that self-placed order to satisfy the "real purchase" requirement.
--
-- Live-verified this was genuinely exploitable before this fix: as a single
-- test account, inserted a `__TEST__` product as its own seller, called
-- `decrement_product_stock` on it, inserted a `marketplace_orders` row with
-- that same account as buyer, then successfully inserted a
-- `marketplace_reviews` row with that same account as reviewer_id — all
-- three succeeded under the pre-this-migration policy. A bad-faith seller
-- could inflate her own product's rating this way, undermining the entire
-- trust signal `marketplace_reviews_page.dart`'s average-rating display and
-- `product_detail_page.dart`'s review list exist to provide.
--
-- This is the same "no identity may escalate itself" shape already applied
-- to loan approval, meeting attendance decisions, etc. — the reviewer and
-- the party being reviewed must never be the same person.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "marketplace_reviews_insert_authenticated" on public.marketplace_reviews;

create policy "marketplace_reviews_insert_authenticated" on public.marketplace_reviews
  for insert with check (
    auth.role() = 'authenticated'
    and (
      reviewer_id is null
      or (
        reviewer_id = auth.uid()
        and exists (
          select 1 from public.marketplace_orders o
          where o.product_id = marketplace_reviews.product_id
            and o.buyer_id = auth.uid()
        )
        and not exists (
          select 1 from public.marketplace_products p
          where p.id = marketplace_reviews.product_id
            and p.seller_id = auth.uid()
        )
      )
    )
  );
