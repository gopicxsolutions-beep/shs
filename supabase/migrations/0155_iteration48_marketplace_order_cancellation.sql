-- Missing feature, called out by name in this repo's own docs.md (SRS.md,
-- Marketplace §): "there is no buyer-initiated cancellation yet (would need
-- a new 'cancelled' status plus a stock-restore RPC)". Part of the
-- marketplace audit requested this session.
--
-- Scope, deliberately narrow: a buyer may cancel her OWN order only while it
-- is still 'new' — before the seller has done anything with it (packed it,
-- shipped it, ...). Once packing has started, cancellation is a
-- conversation with the seller, not a one-tap undo; this mirrors ordinary
-- e-commerce convention and keeps the change small and clearly correct
-- rather than opening a much bigger "who can cancel what, when" design
-- space. Staff/seller-initiated cancellation and a formal
-- refund/dispute flow are explicitly NOT in this pass.

alter table public.marketplace_orders drop constraint if exists marketplace_orders_status_check;
alter table public.marketplace_orders add constraint marketplace_orders_status_check
  check (status = any (array['new', 'packed', 'shipped', 'delivered', 'cancelled']));

-- Deliberately NOT added to `advance_marketplace_order_status`'s own
-- `v_flow` array (0068) — that RPC is the SELLER/staff-facing forward/
-- back-one-step flow and must never accept 'cancelled' as a target (a
-- seller "advancing" an order to cancelled would skip the stock-restore
-- this dedicated function performs). Cancellation is its own atomic
-- operation for exactly the same reason `place_marketplace_order` is: it
-- touches TWO tables (the order's status AND the product's stock) and
-- needs `security definer` to do that reliably regardless of what RLS on
-- either table currently allows, the same precedent 0057 established.
create or replace function public.cancel_marketplace_order(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
begin
  select * into v_order from public.marketplace_orders where id = p_order_id for update;
  if v_order is null then
    raise exception 'order not found';
  end if;
  if v_order.buyer_id is distinct from auth.uid() then
    raise exception 'not authorized to cancel this order';
  end if;
  if v_order.status <> 'new' then
    raise exception 'this order can no longer be cancelled';
  end if;

  update public.marketplace_orders set status = 'cancelled' where id = p_order_id;
  update public.marketplace_products set stock = stock + v_order.quantity where id = v_order.product_id;
end;
$$;

revoke all on function public.cancel_marketplace_order(uuid) from public, anon;
grant execute on function public.cancel_marketplace_order(uuid) to authenticated;
