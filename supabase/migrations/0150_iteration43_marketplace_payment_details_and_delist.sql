-- Marketplace: seller payment details (UPI ID + optional note) and
-- seller-facing delist/relist.
--
-- Sellers have no DELETE right on marketplace_products
-- (marketplace_products_delete_staff is staff-only, and staff are excluded
-- from deleting their own too — 0105) — so "delist" is a soft `is_active`
-- flag toggled via UPDATE, not a real delete. The existing UPDATE policy
-- (0098) already lets a seller update any column except the locked
-- seller_id/created_at, so no UPDATE policy change is needed for the
-- toggle itself. Only the SELECT policy needs a small addition so a
-- delisted product hides from general browsing while staying visible to
-- its own seller (for her My Listings page) and to staff, and
-- place_marketplace_order() needs an explicit guard so a delisted product
-- can't still be purchased via a direct RPC call even though the UI hides
-- it — RLS/RPC is the real authorization boundary here, not client-side
-- hiding.

alter table public.marketplace_products
  add column upi_id text,
  add column payment_note text,
  add column is_active boolean not null default true;

-- Sanity bound only (defense in depth) — real UPI-handle validation isn't
-- something Postgres should own; the actual payment happens outside this
-- app once the buyer's UPI app opens.
alter table public.marketplace_products
  add constraint marketplace_products_upi_id_length check (upi_id is null or char_length(upi_id) between 3 and 100),
  add constraint marketplace_products_payment_note_length check (payment_note is null or char_length(payment_note) <= 500);

drop policy if exists "marketplace_products_select_all" on public.marketplace_products;

create policy "marketplace_products_select_all" on public.marketplace_products
  for select using (
    (is_active and public.profile_is_active(seller_id))
    or seller_id = auth.uid()
    or public.is_staff()
    or public.buyer_has_order_for_product(id)
  );

-- No changes needed to marketplace_products_insert_seller_or_staff (0127),
-- marketplace_products_update_seller_or_staff (0098), or
-- marketplace_products_delete_staff (0105) — the new columns are neither
-- locked nor restricted, and DELETE staying staff-only is exactly why
-- delist is a soft flag instead of a real delete.

-- Adds an is_active guard to place_marketplace_order(), otherwise
-- unchanged from its currently-live definition (0131) — every other check
-- (buyer active, rate limit, seller deactivated, self-order block) is
-- copied verbatim.
create or replace function public.place_marketplace_order(p_product_id uuid)
returns table (success boolean, price numeric, order_id uuid)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row_count integer;
  v_price numeric;
  v_buyer_name text;
  v_order_id uuid;
  v_seller_id uuid;
  v_recent_orders integer;
begin
  select name into v_buyer_name from public.profiles where id = auth.uid();
  if v_buyer_name is null then
    raise exception 'No profile found for the current user.';
  end if;
  if not public.profile_is_active(auth.uid()) then
    raise exception 'your account has been deactivated';
  end if;

  select count(*) into v_recent_orders
  from public.marketplace_orders
  where buyer_id = auth.uid() and created_at > now() - interval '1 hour';
  if v_recent_orders >= 20 then
    raise exception 'too many orders placed in the last hour';
  end if;

  select seller_id into v_seller_id from public.marketplace_products where id = p_product_id;
  if v_seller_id is not null and not public.profile_is_active(v_seller_id) then
    raise exception 'this product is no longer available';
  end if;
  if v_seller_id = auth.uid() then
    raise exception 'you cannot order your own product';
  end if;
  if not exists (select 1 from public.marketplace_products where id = p_product_id and is_active) then
    raise exception 'this product is no longer available';
  end if;

  update public.marketplace_products
  set stock = stock - 1
  where id = p_product_id and stock > 0
  returning marketplace_products.price into v_price;

  get diagnostics v_row_count = row_count;

  if v_row_count = 0 then
    select p.price into v_price from public.marketplace_products p where p.id = p_product_id;
    return query select false, v_price, null::uuid;
    return;
  end if;

  insert into public.marketplace_orders (product_id, buyer_name, buyer_id, amount, status)
  values (p_product_id, v_buyer_name, auth.uid(), v_price, 'new')
  returning id into v_order_id;

  return query select true, v_price, v_order_id;
end;
$$;

revoke all on function public.place_marketplace_order(uuid) from public, anon;
grant execute on function public.place_marketplace_order(uuid) to authenticated;
