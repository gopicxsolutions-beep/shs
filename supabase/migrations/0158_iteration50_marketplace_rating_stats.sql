-- Marketplace audit finding: no average rating was shown anywhere in the
-- app — not on the browse grid, not on the product detail header. A buyer
-- had to open every listing individually and scroll all the way down to
-- the reviews section just to get any sense of quality, defeating the
-- point of having reviews at all when comparing products.
--
-- Computing this per-product with a live aggregate query at read time would
-- be an N+1 query against every product in the grid (this repo's own
-- CLAUDE.md explicitly calls this out to avoid). Instead, mirror the exact
-- pattern migration 0124 already established for `seller_name`: pin the
-- aggregate onto `marketplace_products` itself, kept current by a trigger,
-- so every existing read path (`fetchProducts`/`fetchProductById`/
-- `fetchMyProducts`, all bare `.select()`) picks it up for free with zero
-- extra round trips. Unlike `seller_name` (BEFORE trigger on the product's
-- own insert/update, since the source data — the seller's name — lives on
-- a different row entirely), this is an AFTER trigger on `marketplace_
-- reviews` insert/delete (there is no review UPDATE path yet — see
-- migration 0157's own scoping note), since the source data lives on a
-- DIFFERENT table than the one being kept in sync — this needs `security
-- definer` for the trigger to write `marketplace_products` regardless of
-- the firing user's own RLS write access to that row (an ordinary reviewer
-- has none).

alter table public.marketplace_products add column if not exists avg_rating numeric(3, 2);
alter table public.marketplace_products add column if not exists review_count int not null default 0;

create or replace function public.marketplace_products_refresh_rating_stats(p_product_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.marketplace_products mp
    set review_count = agg.cnt,
        avg_rating = agg.avg_rating
    from (
      select count(*) as cnt, avg(rating)::numeric(3, 2) as avg_rating
      from public.marketplace_reviews
      where product_id = p_product_id
    ) agg
    where mp.id = p_product_id;
end;
$$;

revoke all on function public.marketplace_products_refresh_rating_stats(uuid) from public, anon;

create or replace function public.marketplace_reviews_refresh_product_stats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.marketplace_products_refresh_rating_stats(old.product_id);
    return old;
  else
    perform public.marketplace_products_refresh_rating_stats(new.product_id);
    return new;
  end if;
end;
$$;

drop trigger if exists marketplace_reviews_refresh_product_stats_trigger on public.marketplace_reviews;
create trigger marketplace_reviews_refresh_product_stats_trigger
  after insert or delete on public.marketplace_reviews
  for each row
  execute function public.marketplace_reviews_refresh_product_stats();

-- One-time backfill for every review already posted before this trigger
-- existed. `avg_rating` stays null (not 0) for a product with zero
-- reviews — matches the UI's existing "No reviews yet" language rather than
-- implying a real rating of zero stars.
update public.marketplace_products mp
  set review_count = agg.cnt,
      avg_rating = agg.avg_rating
  from (
    select product_id, count(*) as cnt, avg(rating)::numeric(3, 2) as avg_rating
    from public.marketplace_reviews
    group by product_id
  ) agg
  where mp.id = agg.product_id;
