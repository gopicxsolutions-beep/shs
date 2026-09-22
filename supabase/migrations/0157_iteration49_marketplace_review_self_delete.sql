-- Marketplace audit finding #17: a reviewer had no way to delete her own
-- review at all. Only `marketplace_reviews_delete_staff` existed (staff
-- moderating someone ELSE's review — deliberately excludes a staff member's
-- own review, see migration 0106's anti-self-dealing comment). A buyer who
-- regretted a comment, or wanted to correct a rating she got wrong, had to
-- ask staff to do it for her, which the app has no in-product way to even
-- request.
--
-- Delete-only (not update/edit) for this round: this is the simpler, more
-- safety-critical half of the finding (retracting something already posted)
-- and needs no locked-fields WITH CHECK machinery, unlike an edit policy
-- would. Multiple DELETE policies on the same table are OR'd together by
-- Postgres RLS, so this is additive and doesn't touch the existing staff
-- policy's behavior at all.

drop policy if exists "marketplace_reviews_delete_own" on public.marketplace_reviews;

create policy "marketplace_reviews_delete_own" on public.marketplace_reviews
  for delete using (reviewer_id = auth.uid());
