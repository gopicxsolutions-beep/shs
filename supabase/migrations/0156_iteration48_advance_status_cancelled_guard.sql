-- Follow-on to 0155 (buyer-initiated order cancellation), caught before
-- shipping by re-reading `advance_marketplace_order_status` (0068) with
-- 'cancelled' now a valid status in mind, not by anyone hitting it live.
--
-- `p_new_status = 'cancelled'` was already blocked (`array_position(v_flow,
-- 'cancelled')` is null, since 'cancelled' was deliberately never added to
-- v_flow — see 0155's own comment on why). But the REVERSE direction — the
-- order's CURRENT status already being 'cancelled' — was not: for a
-- cancelled order, `array_position(v_flow, 'cancelled')` (v_cur_idx) is
-- null, so the non-staff one-step-transition check `abs(v_new_idx -
-- v_cur_idx) <> 1` evaluates to `abs(v_new_idx - null) <> 1`, which is null
-- — and `if null then ... end if` in plpgsql treats a null condition as
-- false, silently skipping the `raise exception` and falling through to the
-- UPDATE. Both a non-staff seller AND staff (who skip the one-step check
-- entirely) could therefore "advance" a cancelled order to any other
-- status, resurrecting it — critically, without ever re-decrementing the
-- stock `cancel_marketplace_order` restored, letting the same units be sold
-- twice (once via the original, still-open buyer relationship on the
-- resurrected order, and again via any new order placed against the
-- now-inflated stock count in between).
create or replace function public.advance_marketplace_order_status(p_order_id uuid, p_new_status text)
returns void
language plpgsql
set search_path = 'public'
as $function$
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

  if v_status = 'cancelled' then
    raise exception 'this order was cancelled and cannot be advanced';
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
$function$;
