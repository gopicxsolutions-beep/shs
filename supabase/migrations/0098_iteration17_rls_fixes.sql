-- Gap-hunt round 189 (iteration 17): fixes from this round's 4 fresh
-- audits (dogfooding round 188 — grant hygiene, handled separately in
-- 0095-0097; Loans full lifecycle; Meetings/Attendance/Notifications;
-- Marketplace + Financial Ledger). This migration covers the remaining
-- RLS-layer findings; Dart-side fixes ship in the same commit.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [HIGH, Loans audit] `record_loan_payment` (0088) never checked the
--    loan's own status before recording a payment, unlike its siblings
--    `approve_loan`/`reject_loan` which both explicitly reject anything
--    but `pending`. Any leader/staff could call the RPC directly against a
--    still-`pending` or already-`rejected` loan and flip it straight to
--    `closed` (since `apply()` already sets `outstanding = amount` at
--    insert time) — skipping approval entirely, with `disbursed_on`/`emi`/
--    `decided_by` all left null and zero audit-trail row (`audit_loan_
--    decision()` only fires on `pending -> active/rejected`, never
--    `-> closed`), while `AnalyticsRepository.fetchPlatformKpis` still
--    counts it as a genuinely disbursed, closed loan. Fixed by adding the
--    same status guard `approve_loan`/`reject_loan` already have.
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.record_loan_payment(p_loan_id uuid, p_amount numeric)
returns table (new_outstanding numeric, closed boolean, new_next_due_date date)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_outstanding numeric;
  v_status text;
  v_new_outstanding numeric;
  v_new_next_due_date date;
  v_shg_id uuid;
  v_member_id uuid;
begin
  if p_amount <= 0 then
    raise exception 'payment amount must be positive';
  end if;

  select outstanding, status, shg_id, member_id into v_current_outstanding, v_status, v_shg_id, v_member_id
  from public.loans
  where id = p_loan_id
  for update;

  if v_current_outstanding is null then
    raise exception 'loan not found';
  end if;
  if v_status not in ('active', 'overdue') then
    raise exception 'loan is not open for payment (current status: %)', v_status;
  end if;
  if v_member_id = auth.uid() then
    raise exception 'cannot record a payment on your own loan';
  end if;
  if not ((v_shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()) then
    raise exception 'not authorized to record a payment on this loan';
  end if;
  if p_amount > v_current_outstanding then
    raise exception 'payment amount (%) exceeds outstanding balance (%)', p_amount, v_current_outstanding;
  end if;

  insert into public.loan_payments (loan_id, amount) values (p_loan_id, p_amount);

  v_new_next_due_date := case when v_current_outstanding - p_amount <= 0 then null else current_date + interval '30 days' end;

  update public.loans
  set outstanding = v_current_outstanding - p_amount,
      status = case when v_current_outstanding - p_amount <= 0 then 'closed' else status end,
      next_due_date = v_new_next_due_date
  where id = p_loan_id
  returning outstanding into v_new_outstanding;

  return query select v_new_outstanding, v_new_outstanding <= 0, v_new_next_due_date;
end;
$$;

revoke all on function public.record_loan_payment(uuid, numeric) from public, anon;
grant execute on function public.record_loan_payment(uuid, numeric) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. [HIGH, Meetings audit] `meeting_attendance`'s self-check-in "same day"
--    guard compared `m.meeting_date` against bare `current_date`, which
--    runs in the Postgres server's UTC clock (no `timezone` override
--    anywhere in this project) — but the app's own "is this meeting today"
--    logic (`Meeting.isScheduledToday`) uses the device's local IST
--    (UTC+5:30) clock. IST's calendar day starts 5.5 hours before UTC's,
--    so from 00:00-05:29 IST every day, a genuinely same-day meeting's
--    self-check-in was rejected by RLS (UTC still says "yesterday") even
--    though the UI correctly showed the Check-In button — a real member
--    hitting a daily 5.5-hour window where check-in silently fails with
--    only a generic error. Fixed by comparing against the IST calendar
--    date instead of the server's own UTC date, on both the INSERT (0091)
--    and UPDATE (0090) self-branches.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meeting_attendance_insert_self_or_leader" on public.meeting_attendance;

create policy "meeting_attendance_insert_self_or_leader" on public.meeting_attendance
  for insert with check (
    (
      member_id = auth.uid()
      and exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.shg_id = public.current_shg_id()
          and m.status <> 'cancelled'
          and m.meeting_date = (now() at time zone 'Asia/Kolkata')::date
      )
    )
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and m.status <> 'cancelled'
        and public.current_role() = 'leader'
        and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
        and public.profile_is_active(meeting_attendance.member_id)
    )
    or (public.is_staff() and public.profile_is_active(meeting_attendance.member_id))
  );

drop policy if exists "meeting_attendance_update_self_or_leader" on public.meeting_attendance;

create policy "meeting_attendance_update_self_or_leader" on public.meeting_attendance
  for update using (
    member_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_attendance.meeting_id
        and m.shg_id = public.current_shg_id()
        and m.status <> 'cancelled'
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  ) with check (
    (public.is_staff() and public.profile_is_active(meeting_attendance.member_id))
    or (
      (
        member_id = auth.uid()
        and exists (
          select 1 from public.meetings m
          where m.id = meeting_attendance.meeting_id
            and m.shg_id = public.current_shg_id()
            and m.status <> 'cancelled'
            and m.meeting_date = (now() at time zone 'Asia/Kolkata')::date
        )
      )
      or exists (
        select 1 from public.meetings m
        where m.id = meeting_attendance.meeting_id
          and m.shg_id = public.current_shg_id()
          and m.status <> 'cancelled'
          and public.current_role() = 'leader'
          and public.profile_shg_id(meeting_attendance.member_id) = m.shg_id
          and public.profile_is_active(meeting_attendance.member_id)
      )
    ) and (
      meeting_id = (select f.meeting_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
      and member_id = (select f.member_id from public.meeting_attendance_locked_fields(meeting_attendance.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. [MEDIUM, Meetings audit] `meeting_action_items_update_self_or_leader`'s
--    bare self-toggle branch (`owner_id = auth.uid()`) never checked
--    `profile_is_active(owner_id)`, unlike the leader-assigning branch two
--    lines below it (which already has the check) — the 6th table in the
--    same repeating pattern rounds 184-187 closed one at a time
--    (savings_entries, livelihood_activities, meeting_attendance,
--    course_progress, support_messages). A deactivated member's still-
--    valid session could keep toggling her own action items indefinitely.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "meeting_action_items_update_self_or_leader" on public.meeting_action_items;

create policy "meeting_action_items_update_self_or_leader" on public.meeting_action_items
  for update using (
    owner_id = auth.uid()
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
    )
    or public.is_staff()
  ) with check (
    public.is_staff()
    or (
      owner_id = auth.uid()
      and public.profile_is_active(owner_id)
      and meeting_id is not distinct from (select f.meeting_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
      and task is not distinct from (select f.task from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
      and owner_id is not distinct from (select f.owner_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
      and due_date is not distinct from (select f.due_date from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
    )
    or exists (
      select 1 from public.meetings m
      where m.id = meeting_action_items.meeting_id
        and m.shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and (owner_id is null or (public.profile_shg_id(owner_id) = m.shg_id and public.profile_is_active(owner_id)))
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 4. [HIGH, Marketplace audit] The `profile_is_active()` sweep (rounds
--    184-187) never reached the SELLER side of Marketplace — only the
--    buyer's own active status was ever checked (`place_marketplace_
--    order`, 0091). A staff-deactivated seller's still-valid session could
--    keep listing new products, editing price/stock/description, and
--    advancing order status (including marking "delivered") indefinitely,
--    and her existing listings stayed fully visible/purchasable to any
--    buyer with zero indication anything changed. Fixed on all three
--    seller-facing policies plus the order-placement RPC (checking the
--    resolved seller, not just the buyer).
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "marketplace_products_insert_seller_or_staff" on public.marketplace_products;

create policy "marketplace_products_insert_seller_or_staff" on public.marketplace_products
  for insert with check (
    (seller_id = auth.uid() and public.profile_is_active(seller_id))
    or public.is_staff()
  );

drop policy if exists "marketplace_products_update_seller_or_staff" on public.marketplace_products;

create policy "marketplace_products_update_seller_or_staff" on public.marketplace_products
  for update using ((seller_id = auth.uid() and public.profile_is_active(seller_id)) or public.is_staff())
  with check (
    ((seller_id = auth.uid() and public.profile_is_active(seller_id)) or public.is_staff())
    and seller_id = (select f.seller_id from public.marketplace_products_locked_fields(marketplace_products.id) f)
    and created_at = (select f.created_at from public.marketplace_products_locked_fields(marketplace_products.id) f)
  );

drop policy if exists "marketplace_orders_update_seller_or_staff" on public.marketplace_orders;

create policy "marketplace_orders_update_seller_or_staff" on public.marketplace_orders
  for update using (
    exists (select 1 from public.marketplace_products p where p.id = product_id and p.seller_id = auth.uid() and public.profile_is_active(p.seller_id))
    or public.is_staff()
  )
  with check (
    (
      exists (select 1 from public.marketplace_products p where p.id = product_id and p.seller_id = auth.uid() and public.profile_is_active(p.seller_id))
      or public.is_staff()
    )
    and product_id = (select l.product_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and buyer_id is not distinct from (select l.buyer_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and buyer_name = (select l.buyer_name from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and amount = (select l.amount from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and order_date = (select l.order_date from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and created_at = (select l.created_at from public.marketplace_order_locked_fields(marketplace_orders.id) l)
  );

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
begin
  select name into v_buyer_name from public.profiles where id = auth.uid();
  if v_buyer_name is null then
    raise exception 'No profile found for the current user.';
  end if;
  if not public.profile_is_active(auth.uid()) then
    raise exception 'your account has been deactivated';
  end if;

  select seller_id into v_seller_id from public.marketplace_products where id = p_product_id;
  if v_seller_id is not null and not public.profile_is_active(v_seller_id) then
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
