-- Gap-hunt iteration 30: Marketplace full sweep, 1 HIGH finding.
--
-- `marketplace_products` had no pinned seller-display-name column — unlike
-- `marketplace_orders.buyer_name`/`marketplace_reviews.reviewer_name`
-- (migration 0069), which exist as text columns pinned server-side
-- specifically so display doesn't depend on a live, RLS-gated join. The
-- seller's name instead depended on a PostgREST embed of `profiles(name)`
-- in every repository read (`fetchProducts`/`fetchProductById`/
-- `fetchMyProducts`) — but `profiles_select_self_shg_or_staff` only allows
-- `id = auth.uid() OR shg_id = current_shg_id() OR is_staff()`, with no
-- exception for Marketplace's explicitly cross-SHG design (SRS §3.8: "any
-- other member across the whole platform can browse and buy"). A denied
-- embed doesn't error — PostgREST silently returns `profiles: null`, which
-- `Product.fromMap` swallows into the fallback string `'Seller'`. Any buyer
-- not in the seller's own SHG and not staff has been seeing every one of
-- that seller's listings attributed to a generic "Seller" this whole time,
-- silently, with no error surfaced anywhere — the marketplace's own core
-- "browse across the whole platform" feature showing wrong attribution for
-- the majority of real cross-SHG listings. Every other repository using
-- this same `profiles(name)` embed pattern is scoped to same-SHG
-- members/staff (financial_ledger, livelihood_activities, savings_entries,
-- loans, meeting_action_items, support_messages), so this mismatch is
-- unique to Marketplace's genuinely platform-wide design.
--
-- Fixed the same way `marketplace_reviews.reviewer_name` already is:
-- stamp it server-side from `profiles.name` on INSERT, ignoring whatever
-- the client sends (there's nothing to validate here — a seller only ever
-- lists her OWN name, so a stamping trigger, not a with-check comparison,
-- is the right mechanism, mirroring 0069's own reasoning).

alter table public.marketplace_products add column if not exists seller_name text;

-- Backfill existing rows once, for whichever seller's name is currently
-- resolvable (a deactivated/deleted seller's row would leave this null,
-- same fallback-to-'Seller' behavior as before for that edge case only).
update public.marketplace_products mp
  set seller_name = p.name
  from public.profiles p
  where p.id = mp.seller_id and mp.seller_name is null;

alter table public.marketplace_products alter column seller_name set not null;

-- Unlike `marketplace_reviews` (never editable after posting, so an
-- INSERT-only pin was enough for `reviewer_name`), a product IS routinely
-- edited (description/price/stock) — `marketplace_products_update_seller_
-- or_staff`'s WITH CHECK locks `seller_id`/`created_at` but nothing else,
-- so an UPDATE-only pin would leave `seller_name` client-settable on every
-- edit. Firing on BOTH insert and update keeps it permanently re-derived
-- from the real `profiles.name` (itself already locked to `seller_id`, so
-- this can't be redirected to a different profile), removing any path for
-- the client to control it at all rather than merely validating it.
create or replace function public.marketplace_products_pin_seller_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select p.name into new.seller_name from public.profiles p where p.id = new.seller_id;
  return new;
end;
$$;

drop trigger if exists marketplace_products_pin_seller_name_trigger on public.marketplace_products;
create trigger marketplace_products_pin_seller_name_trigger
  before insert or update on public.marketplace_products
  for each row
  execute function public.marketplace_products_pin_seller_name();
