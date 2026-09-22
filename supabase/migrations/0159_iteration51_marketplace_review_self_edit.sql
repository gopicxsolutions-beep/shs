-- Completes marketplace audit finding #17 (round 10 shipped delete-only,
-- scoped deliberately — see 0157's own note). A reviewer still had no way
-- to fix a typo or correct a rating without deleting the whole review and
-- losing her place (the unique index would also block her from posting a
-- fresh one until the old one's DELETE had actually landed first).
--
-- `marketplace_reviews_locked_fields` was gated `where ... and
-- public.is_staff()` — correct for its original staff-only moderation use,
-- but returns nothing for an ordinary reviewer checking her OWN row, which
-- would make every locked-field comparison below evaluate against NULL and
-- silently reject every edit. Widened to also match the row's own author.
-- This discloses nothing new: `product_id`/`reviewer_id`/`reviewer_name`/
-- `created_at` are already readable by anyone via the existing `marketplace_
-- reviews_select_all` policy — this function only ever gates a WITH CHECK
-- comparison, never a SELECT.

create or replace function public.marketplace_reviews_locked_fields(p_id uuid)
returns table (product_id uuid, reviewer_id uuid, reviewer_name text, created_at timestamptz)
language sql
stable security definer
set search_path = public
as $$
  select r.product_id, r.reviewer_id, r.reviewer_name, r.created_at
  from public.marketplace_reviews r
  where r.id = p_id and (public.is_staff() or r.reviewer_id = auth.uid());
$$;

-- Same shape as `marketplace_reviews_moderate_staff` (0106), scoped to the
-- review's own author instead of staff, and — unlike that policy — with no
-- self-exclusion: a staff member editing HER OWN review is exercising an
-- ordinary reviewer's right, not a moderation power, exactly the same
-- distinction `marketplace_reviews_delete_own` (0157) already draws for
-- deletion. Only rating/comment are left open to change.

drop policy if exists "marketplace_reviews_update_own" on public.marketplace_reviews;

create policy "marketplace_reviews_update_own" on public.marketplace_reviews
  for update using (reviewer_id = auth.uid())
  with check (
    reviewer_id = auth.uid()
    and product_id = (select f.product_id from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
    and reviewer_id = (select f.reviewer_id from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
    and reviewer_name = (select f.reviewer_name from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
    and created_at = (select f.created_at from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
  );

-- migration 0158's `avg_rating`/`review_count` trigger only fired on
-- INSERT/DELETE, since editing a review's rating wasn't possible yet. Now
-- that it is, an edited rating would silently leave the pinned average
-- stale until some unrelated insert/delete on the same product happened to
-- refresh it. `review_count` never changes on an UPDATE (still the same
-- number of rows), only `avg_rating` can — but re-running the same
-- idempotent aggregate for both costs nothing extra to justify a narrower
-- `update of rating` trigger condition.

drop trigger if exists marketplace_reviews_refresh_product_stats_trigger on public.marketplace_reviews;
create trigger marketplace_reviews_refresh_product_stats_trigger
  after insert or update or delete on public.marketplace_reviews
  for each row
  execute function public.marketplace_reviews_refresh_product_stats();
