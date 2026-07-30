-- Fixes a mistake in 0143, caught by live verification before it was ever
-- exposed to the app (never worked in production): the new EXISTS clause
-- in `marketplace_products_select_all` queries `marketplace_orders`
-- directly, but `marketplace_orders_select_related`'s own policy queries
-- BACK into `marketplace_products` (to check `seller_id = auth.uid()`) —
-- exactly the self-referencing-subquery-across-two-tables recursion
-- CLAUDE.md's own house rules warn about (`42P17`), live-confirmed:
-- `ERROR: infinite recursion detected in policy for relation
-- "marketplace_products"`.
--
-- Fixed the same way this codebase's own established pattern handles it —
-- a `security definer` helper that queries the table directly, bypassing
-- RLS for that one inner check, so the cycle never forms.
create or replace function public.buyer_has_order_for_product(p_product_id uuid)
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select exists (
    select 1 from public.marketplace_orders o
    where o.product_id = p_product_id and o.buyer_id = auth.uid()
  );
$$;

revoke all on function public.buyer_has_order_for_product(uuid) from public, anon;
grant execute on function public.buyer_has_order_for_product(uuid) to authenticated;

drop policy if exists "marketplace_products_select_all" on public.marketplace_products;
create policy "marketplace_products_select_all" on public.marketplace_products
  for select using (
    public.profile_is_active(seller_id)
    or public.is_staff()
    or public.buyer_has_order_for_product(id)
  );
