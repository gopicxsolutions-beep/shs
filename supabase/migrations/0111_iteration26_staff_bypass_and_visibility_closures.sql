-- Gap-hunt iteration 26 (round 199): 4 parallel audits (dogfood round 198,
-- Livelihood Activities, Scheme Catalog/Applications, Marketplace full
-- sweep). This migration closes every RLS/backend gap found.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [HIGH] `meeting_action_items_update_self_or_leader`'s `is_staff()`
--    branch was a fully independent top-level `or` in the `with check`,
--    never ANDed with the locked-fields clause — the exact bug shape
--    migration 0110 fixed for `meeting_attendance_update_self_or_leader`
--    (CRITICAL) and `meetings_update_leader_or_staff` (HIGH) in the SAME
--    "Meetings/Attendance/Minutes" audit area, just never checked on this
--    sibling table. Any staff account could PATCH any action item and
--    freely rewrite `meeting_id`/`owner_id`/`task`/`due_date` with no
--    self-exclusion or scope check. Fixed by ANDing the locked-fields
--    check onto the staff branch too, same shape as 0110's fix.
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
    (
      public.is_staff()
      or (
        owner_id = auth.uid()
        and public.profile_is_active(owner_id)
      )
      or exists (
        select 1 from public.meetings m
        where m.id = meeting_action_items.meeting_id
          and m.shg_id = public.current_shg_id()
          and public.current_role() = 'leader'
          and (owner_id is null or (public.profile_shg_id(owner_id) = m.shg_id and public.profile_is_active(owner_id)))
      )
    ) and (
      meeting_id is not distinct from (select f.meeting_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
      and task is not distinct from (select f.task from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
      and owner_id is not distinct from (select f.owner_id from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
      and due_date is not distinct from (select f.due_date from public.meeting_action_items_locked_fields(meeting_action_items.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. [HIGH] `marketplace_orders_update_seller_or_staff`'s `is_staff()`
--    branch had no self-exclusion — a staff account could buy her own
--    product (via a different seller's listing) or any product, then
--    directly UPDATE her own order's `status` straight to `'delivered'`
--    with none of the seller branch's one-step-transition guard, then
--    immediately post a "verified purchase" review — exactly the fraud
--    vector `marketplace_reviews_insert_authenticated`'s delivered-order
--    requirement (0061/0068) exists to prevent, just reached via a staff
--    account instead of a forged order. Fixed by adding
--    `buyer_id is distinct from auth.uid()` to the staff branch, matching
--    the self-exclusion precedent on every other staff branch this table
--    family has needed this session. Staff retains its broader ability to
--    manage/correct OTHER buyers'/sellers' orders unrestricted by the
--    one-step guard — only self-dealing is newly blocked.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "marketplace_orders_update_seller_or_staff" on public.marketplace_orders;

create policy "marketplace_orders_update_seller_or_staff" on public.marketplace_orders
  for update using (
    (exists (select 1 from public.marketplace_products p where p.id = marketplace_orders.product_id and p.seller_id = auth.uid() and public.profile_is_active(p.seller_id)))
    or public.is_staff()
  )
  with check (
    (
      (public.is_staff() and buyer_id is distinct from auth.uid())
      or (
        (exists (select 1 from public.marketplace_products p where p.id = marketplace_orders.product_id and p.seller_id = auth.uid() and public.profile_is_active(p.seller_id)))
        and abs(
          array_position(array['new','packed','shipped','delivered'], status)
          - array_position(array['new','packed','shipped','delivered'], (select l.status from public.marketplace_order_locked_fields(marketplace_orders.id) l))
        ) = 1
      )
    )
    and product_id = (select l.product_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and buyer_id is not distinct from (select l.buyer_id from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and buyer_name = (select l.buyer_name from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and amount = (select l.amount from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and order_date = (select l.order_date from public.marketplace_order_locked_fields(marketplace_orders.id) l)
    and created_at = (select l.created_at from public.marketplace_order_locked_fields(marketplace_orders.id) l)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. [MEDIUM] `place_marketplace_order` never blocked a seller from buying
--    her own listing — `0048`'s own comment already flagged this ("nothing
--    stopped a seller from placing an order against her own listing") but
--    only ever closed the reviewing half (seller can't review her own
--    product). Combined with finding #2 above, an unrestricted self-order
--    was the missing first step of the fake-review fraud chain. Closing
--    it at the source rather than only downstream.
-- ─────────────────────────────────────────────────────────────────────────

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
  if v_seller_id = auth.uid() then
    raise exception 'you cannot order your own product';
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

-- ─────────────────────────────────────────────────────────────────────────
-- 4. [LOW] `course_progress_select_related` (0037) was never dropped when
--    0110 split the old `for all` policy into explicit per-command
--    policies, including a new `course_progress_select_self_or_staff` with
--    an identical condition — two permissive SELECT policies now coexist
--    with no functional difference today, but it's a footgun: a future
--    round narrowing SELECT access by editing only the new policy would
--    silently not restrict anything, since the old one still grants the
--    same broad access. Dropping the now-redundant original.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "course_progress_select_related" on public.course_progress;

-- ─────────────────────────────────────────────────────────────────────────
-- 5. [MEDIUM] `scheme_applications.decided_by` (migration 0050) attributes
--    every staff decision to a real profile, surfaced to the applicant as
--    "Decided by {name}" on her own scheme_tracking_page.dart — but no
--    `profiles` SELECT policy ever granted the applicant visibility into
--    the DECIDER's row when the decider is staff. `profiles_select_self_
--    shg_or_staff` (0002) is `id = auth.uid() or shg_id = current_shg_id()
--    or is_staff()`, evaluated with the APPLICANT as the caller — since
--    crp/clf/admin accounts have no `shg_id` of their own (documented
--    throughout docs/SRS.md), `decider.shg_id = current_shg_id()` can
--    never be true, and `is_staff()` evaluates the CALLER (the applicant,
--    not staff), so it's also false. PostgREST silently returns `null`
--    for the embed rather than erroring, so the feature just quietly
--    doesn't work for the realistic case (a staff-decided application) —
--    the exact bug shape migration 0045 already fixed once for
--    `shg_join_requests`' decider visibility, just never mirrored here.
--    Adding the same shaped policy: an applicant may see the profile of
--    whoever decided HER OWN application.
-- ─────────────────────────────────────────────────────────────────────────

create policy "profiles_select_scheme_decider" on public.profiles
  for select using (
    exists (
      select 1 from public.scheme_applications a
      where a.decided_by = profiles.id
        and a.member_id = auth.uid()
    )
  );
