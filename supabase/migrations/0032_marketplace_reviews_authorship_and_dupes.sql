-- Full marketplace-reviews audit (this session had touched marketplace order
-- status races in round 68, but never done a dedicated pass on Reviews).
-- Surfaced the exact gap 0015_insert_check_scope_gaps.sql explicitly
-- disclosed-but-deferred for this table ("Explicitly disclosed, NOT fixed"
-- section, near the bottom of that file): `marketplace_reviews_insert_
-- authenticated` was `for insert with check (auth.role() = 'authenticated')`
-- — the loosest possible check, identical in shape to marketplace_orders'
-- pre-0015 `buyer_id` gap. There was no identity-bearing column on this
-- table at all (only a free-text `reviewer_name`), so 0015 correctly judged
-- adding one out of scope for a with-check-only migration and flagged it for
-- later prioritization instead of silently leaving it unmentioned. This is
-- that follow-up.
--
-- Concretely, with the policy as it shipped: ANY authenticated member —
-- buyer, seller, or a total stranger who never viewed the product — could
-- insert a review for ANY product, under any free-text `reviewer_name`
-- (real or fabricated), any number of times, with nothing tying the row
-- back to the caller's real identity or to an actual purchase. A seller
-- could 5-star their own listing under a fake name, a competitor could
-- 1-star a rival's product having never bought it, and the same real buyer
-- could spam a product with dozens of identical 5-star reviews — every
-- rating average in the app (`marketplace_reviews_page.dart`'s seller
-- summary, computed fresh from all fetched rows on every load — confirmed
-- NOT a stored/cached aggregate, so no separate race-condition risk there)
-- would silently reflect the fabricated rows with no way to tell them from
-- genuine ones.
--
-- Fix, in the same shape as 0015's `buyer_id` fix for marketplace_orders:
-- 1. Add a real `reviewer_id` FK column (nullable, matching `buyer_id`'s
--    original nullable design for any caller with no linked profile — the
--    same tolerance `marketplace_orders_insert_authenticated` (0015) uses).
-- 2. `with check` requires `reviewer_id` to be null or exactly the caller's
--    own id (no impersonating another member under their real name) AND,
--    whenever it IS set, that the caller actually has an order for this
--    product — closing the "review something you never bought" gap.
-- 3. A partial unique index on (product_id, reviewer_id) stops the same
--    identified buyer leaving more than one review for the same product —
--    duplicate-review spam was previously unbounded (no constraint at all).
--
-- Note: `MarketplaceRepository.addReview()` is not called from any page in
-- this app today (verified — there is no "write a review" screen yet, so in
-- practice this table can currently only be written to via a direct
-- REST/PostgREST call, not through the app UI). Closing this at the schema
-- boundary now means the gap can't resurface silently whenever that UI
-- eventually ships — the server, not the not-yet-written client, is the
-- actual source of truth, matching every other insert/update lockdown in
-- this schema (0009, 0012, 0015, 0022, 0027, 0030, ...).

alter table public.marketplace_reviews add column if not exists reviewer_id uuid references public.profiles (id);

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
      )
    )
  );

-- One review per identified buyer per product. A standard unique index
-- excludes NULLs by default, so this only constrains rows that DO carry a
-- real `reviewer_id` — matching the nullable tolerance above and leaving
-- any legitimately-null-reviewer row (no linked profile) unconstrained,
-- the same trade-off already accepted for `marketplace_orders.buyer_id`.
create unique index if not exists marketplace_reviews_product_reviewer_uniq
  on public.marketplace_reviews (product_id, reviewer_id)
  where reviewer_id is not null;
