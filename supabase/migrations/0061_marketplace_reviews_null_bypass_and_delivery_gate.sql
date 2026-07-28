-- marketplace_reviews_insert_authenticated: close the reviewer_id IS NULL
-- bypass, and require the underlying order to actually be delivered.
--
-- Found during a broad gap-hunting audit, not from a support report.
-- `0032_marketplace_reviews_authorship_and_dupes.sql` and
-- `0048_marketplace_reviews_no_self_review.sql` added real protection for
-- an IDENTIFIED review (reviewer_id = auth.uid()): must have a real order
-- for the product, can't be the product's own seller, and a partial unique
-- index (`reviewer_id IS NOT NULL`) blocks a second review from the same
-- person. But the policy's `with check` OR's that whole branch against
-- `reviewer_id is null`, which requires nothing but
-- `auth.role() = 'authenticated'` — no purchase, no self-review block, and
-- the partial unique index doesn't apply to NULL rows at all. Any
-- authenticated member can `insert into marketplace_reviews (product_id,
-- reviewer_id, reviewer_name, rating, comment) values (<any product>, null,
-- '<anything>', 1, '...')` unlimited times, for any product, without ever
-- having ordered it — fully defeating the review-bombing/fake-review
-- protection three separate migrations were written to add.
--
-- `MarketplaceRepository.addReview()` (lib/repositories/marketplace_repository.dart)
-- always passes the caller's real `appState.profile?.id`, and is gated by
-- `if (!_live) return` so it's never even called in demo mode — there is no
-- live code path that legitimately relies on an anonymous/null-reviewer
-- review, so the `reviewer_id is null` branch has no feature behind it. It
-- was reachable only via a direct REST call, not through the app UI, but
-- per this project's own standing rule ("RLS in Postgres is authorization.
-- Client-side role checks are UX only"), that's exactly the class of gap
-- this migration exists to close — the same framing used by
-- `0018_marketplace_orders_recursion_fix.sql`'s own locked-fields policy.
--
-- Also tightens the purchase check itself: `o.buyer_id = auth.uid()` alone
-- accepted an order in ANY status ('new'/'packed'/'shipped'), letting a
-- buyer post a review the moment she places an order, before the seller
-- has shipped anything. Reviews are meant to attest to the actual product
-- received, so this now requires `o.status = 'delivered'`.
--
-- Live-verified before this fix: as a fresh authenticated session with no
-- order at all, `insert into marketplace_reviews (product_id, reviewer_id,
-- reviewer_name, rating, comment) values ('<seeded __TEST__ product>', null,
-- 'x', 1, 'y')` succeeded. After this migration, the same statement is
-- rejected (0 rows affected).

drop policy if exists "marketplace_reviews_insert_authenticated" on public.marketplace_reviews;

create policy "marketplace_reviews_insert_authenticated" on public.marketplace_reviews
  for insert with check (
    reviewer_id = auth.uid()
    and exists (
      select 1 from public.marketplace_orders o
      where o.product_id = marketplace_reviews.product_id
        and o.buyer_id = auth.uid()
        and o.status = 'delivered'
    )
    and not exists (
      select 1 from public.marketplace_products p
      where p.id = marketplace_reviews.product_id
        and p.seller_id = auth.uid()
    )
  );
