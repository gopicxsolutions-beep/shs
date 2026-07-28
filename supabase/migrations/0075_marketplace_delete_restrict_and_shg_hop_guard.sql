-- Two more gaps found in a fresh audit of marketplace products and the SHG
-- join-request lifecycle.
--
-- 1. `marketplace_orders.product_id` / `marketplace_reviews.product_id`
--    were still `on delete cascade` (0001_init_schema.sql). 0039 correctly
--    restricted `marketplace_products` DELETE to `is_staff()` (closing the
--    self-service-seller-abuse angle), but never touched the underlying
--    FKs — and `is_staff()` covers crp/clf/admin alike, not just admin. Any
--    CRP or CLF account can delete a product and cascade away every order
--    ever placed against it (including already-`'delivered'`, paid
--    transactions) and every review, with zero archival. Identical
--    blast-radius shape to what 0063/0072/0074 already fixed for loans,
--    financial_ledger, and scheme_applications — same fix here.
--
-- 2. `shg_join_requests_insert_self` (0004) never checked the caller's
--    CURRENT `profiles.shg_id` — only the router's `needsShgApproval` gate
--    (shgId == null) stopped an already-approved member from filing a
--    fresh join request to a DIFFERENT SHG, and per this schema's own
--    security model that client-side gate is UX only. The partial unique
--    index (0004) only blocks a second PENDING row; it doesn't stop a new
--    request once a prior one is already `'approved'`. If a different
--    SHG's leader then approves it — via a page that shows only name +
--    mobile, nothing indicating the requester already belongs elsewhere —
--    `approve_shg_join_request` silently moves `profiles.shg_id` from the
--    old SHG to the new one with no visible "leaving" step. Fix: an
--    already-SHG-linked member can no longer submit a new join request at
--    all; switching SHGs needs a deliberate future feature (e.g. an
--    explicit "leave my SHG" action), not a side effect of a leader
--    approving what looks like a brand-new member.

alter table public.marketplace_orders drop constraint marketplace_orders_product_id_fkey;
alter table public.marketplace_orders add constraint marketplace_orders_product_id_fkey foreign key (product_id) references public.marketplace_products (id) on delete restrict;

alter table public.marketplace_reviews drop constraint marketplace_reviews_product_id_fkey;
alter table public.marketplace_reviews add constraint marketplace_reviews_product_id_fkey foreign key (product_id) references public.marketplace_products (id) on delete restrict;

-- Preserves every lifecycle lock 0027 already added (status='pending',
-- requested_at=now(), decided_at/decided_by null) — only adding the new
-- shg_id check on top, not replacing them.
drop policy if exists "shg_join_requests_insert_self" on public.shg_join_requests;

create policy "shg_join_requests_insert_self" on public.shg_join_requests
  for insert with check (
    member_id = auth.uid()
    and status = 'pending'
    and requested_at = now()
    and decided_at is null
    and decided_by is null
    and not exists (select 1 from public.profiles p where p.id = member_id and p.shg_id is not null)
  );
