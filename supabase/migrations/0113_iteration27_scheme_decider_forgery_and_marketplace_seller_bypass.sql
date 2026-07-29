-- Gap-hunt iteration 27 (round 200): 4 parallel audits (dogfood round 199,
-- Notifications system, Admin Monitoring/Reports, Profile/Settings). This
-- migration closes the 2 HIGH RLS gaps the dogfooding audit found.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [HIGH] `scheme_applications_insert_self` never locked `decided_by`/
--    `decided_at` — round 199's new `profiles_select_scheme_decider`
--    policy (migration 0111) is only safe if `decided_by` can never be set
--    by anyone but a real staff decision (`scheme_applications_update_
--    staff`, which correctly locks it to `auth.uid()`). But a member's own
--    INSERT never referenced those two columns at all, so a direct REST
--    call (bypassing the Flutter client, exactly the threat model
--    CLAUDE.md calls out) could submit `decided_by: <any profile uuid>`
--    on an otherwise-legitimate application — instantly granting the
--    submitter permanent `profiles` SELECT access (name, mobile/phone,
--    role, shg_id) on that arbitrary target via the new visibility policy.
--    This is the exact bug class already fixed twice elsewhere in this
--    schema — `shg_join_requests_insert_self` (`and decided_by is null`,
--    migration 0027) and the equivalent lockdown on `loans` (migration
--    0088) — `scheme_applications` never got it because, until 0111 wired
--    a profiles-visibility grant to `decided_by`, nothing read that column
--    for anything but display to the real decider, so the gap was inert.
--    Fixed by mirroring 0027's exact shape.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "scheme_applications_insert_self" on public.scheme_applications;

create policy "scheme_applications_insert_self" on public.scheme_applications
  for insert with check (
    member_id = auth.uid()
    and public.current_role() = 'member'
    and public.profile_is_active(member_id)
    and status = 'applied'
    and applied_on = current_date
    and decided_by is null
    and decided_at is null
    and exists (select 1 from public.schemes s where s.id = scheme_applications.scheme_id and (s.deadline is null or s.deadline >= current_date))
    and public.scheme_eligibility_met(scheme_id, member_id)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. [HIGH] `marketplace_orders_update_seller_or_staff`'s round-199 fix
--    (migration 0111) added a buyer-side self-exclusion to the staff
--    branch (`buyer_id is distinct from auth.uid()`) but missed the
--    seller-side angle: `marketplace_products_insert_seller_or_staff`
--    already lets a staff account legitimately sell her own product, so a
--    staff-seller's OWN order from a genuine third-party buyer still
--    satisfies the staff branch unconditionally — she can force that
--    order's `status` straight to `'delivered'` with none of the ordinary
--    seller branch's one-step-transition guard, without ever shipping.
--    Fixed by also excluding orders on a product the staff account
--    herself sells from the unrestricted staff branch — that case now
--    falls through to the same one-step-guarded seller branch every
--    other seller must obey.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "marketplace_orders_update_seller_or_staff" on public.marketplace_orders;

create policy "marketplace_orders_update_seller_or_staff" on public.marketplace_orders
  for update using (
    (exists (select 1 from public.marketplace_products p where p.id = marketplace_orders.product_id and p.seller_id = auth.uid() and public.profile_is_active(p.seller_id)))
    or public.is_staff()
  )
  with check (
    (
      (
        public.is_staff()
        and buyer_id is distinct from auth.uid()
        and not exists (select 1 from public.marketplace_products p where p.id = marketplace_orders.product_id and p.seller_id = auth.uid())
      )
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
