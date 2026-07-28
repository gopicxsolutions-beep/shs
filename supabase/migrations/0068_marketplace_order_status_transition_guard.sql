-- Marketplace order status: no forward/backward transition guard at all.
--
-- `marketplace_orders_update_seller_or_staff` (0013) deliberately left
-- `status` itself unconstrained in its `with check` — every OTHER column
-- must stay byte-for-byte identical, but `status` was intentionally left
-- free so a seller (or staff) can set it to any of the four enum values.
-- That was a real design choice (staff needs to correct a seller's mistake
-- after the fact), not an oversight — so this fix does NOT reintroduce a
-- blanket lock. But it left a real gap for the non-staff seller path: a
-- seller can jump a brand-new `'new'` order straight to `'delivered'` (or
-- revert an already-`'delivered'` order back to `'new'`) with a single
-- PATCH, no sequencing at all. That directly compounds with 0061's
-- marketplace-reviews fix (review requires `status = 'delivered'`): a
-- seller can instantly self-unlock reviews on an order that was never
-- actually packed/shipped, with no real fulfillment behind it.
--
-- Fix, mirroring `decide_scheme_application` (0029)'s atomic
-- lock-check-update RPC shape: staff keep the existing free-form power
-- (any status, any transition — the correction capability 0013 intended).
-- A non-staff seller is now restricted to moving exactly one step forward
-- or one step back along `['new','packed','shipped','delivered']` per
-- call — still fully able to walk an order through its lifecycle or undo
-- their last own mistake, but can no longer skip straight to `'delivered'`
-- or arbitrarily jump around. `security invoker` so this stays fully
-- subject to `marketplace_orders_update_seller_or_staff`'s existing
-- `using`/`with check` (seller-or-staff gate, all other columns still
-- locked) — this function only adds the missing status-sequencing rule on
-- top, it doesn't replace the RLS policy.

create or replace function public.advance_marketplace_order_status(p_order_id uuid, p_new_status text)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_status text;
  v_flow constant text[] := array['new', 'packed', 'shipped', 'delivered'];
  v_cur_idx int;
  v_new_idx int;
begin
  select status into v_status from public.marketplace_orders where id = p_order_id for update;

  if v_status is null then
    raise exception 'order not found';
  end if;

  v_new_idx := array_position(v_flow, p_new_status);
  if v_new_idx is null then
    raise exception 'invalid status: %', p_new_status;
  end if;

  if not public.is_staff() then
    v_cur_idx := array_position(v_flow, v_status);
    if abs(v_new_idx - v_cur_idx) <> 1 then
      raise exception 'sellers can only move an order one step forward or back (current status: %)', v_status;
    end if;
  end if;

  update public.marketplace_orders set status = p_new_status where id = p_order_id;

  -- security invoker: still subject to marketplace_orders_update_seller_or_staff
  -- (seller-or-staff gate + every-other-column-locked check). FOUND guards
  -- the same silent-0-row-RLS-filter case the loan/scheme decision
  -- functions already guard against.
  if not found then
    raise exception 'not authorized to update this order, or order not found';
  end if;
end;
$$;

revoke all on function public.advance_marketplace_order_status(uuid, text) from public;
grant execute on function public.advance_marketplace_order_status(uuid, text) to authenticated;
