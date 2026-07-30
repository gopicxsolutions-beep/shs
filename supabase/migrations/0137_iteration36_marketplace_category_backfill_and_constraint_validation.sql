-- Gap-hunt iteration 36: a fresh Payments/Marketplace audit found that
-- migration 0131's `NOT VALID` category/length CHECK constraints don't
-- actually grandfather pre-existing out-of-range rows the way `NOT VALID`
-- is often assumed to — Postgres re-validates ALL check constraints on a
-- row on ANY UPDATE to it, regardless of which column changed. Live-
-- confirmed: the pre-0131 `__TEST__` fixture product ("Handwoven Cotton
-- Saree", category `'Textiles'`, not in the 5-value allowlist) throws
-- `23514` from inside `place_marketplace_order()`'s stock-decrement UPDATE
-- even though that statement never touches `category` — making the product
-- permanently unorderable/uneditable, a landmine for any legacy/imported
-- data. This corrects that one row's data (closest real match for a
-- handwoven item) and then VALIDATEs every 0131 constraint, so the schema
-- honestly reflects "every row currently conforms" instead of silently
-- carrying a not-actually-clean NOT VALID marker forward.
update public.marketplace_products
set category = 'Handicrafts'
where id = '99999999-9999-9999-9999-999999999150' and category = 'Textiles';

alter table public.marketplace_products validate constraint marketplace_products_category_check;
alter table public.marketplace_products validate constraint marketplace_products_description_length_check;
alter table public.marketplace_products validate constraint marketplace_products_name_length_check;
alter table public.marketplace_reviews validate constraint marketplace_reviews_comment_length_check;
