-- Gap-hunt iteration 32 (Marketplace/Support Tickets audit): 3 fixes.
--
-- 1. [MEDIUM-HIGH] `support_tickets_update_staff_or_self_reopen`'s staff
-- branch never excluded `member_id = auth.uid()`, unlike the analogous
-- self-dealing guard already applied to `marketplace_orders_update_seller_
-- or_staff` (0113). `support_ticket_detail_page.dart` explicitly claims (and
-- gates its own UI on) "a staff account can never resolve/reassign a ticket
-- she filed herself" — but that was a UI-only guard; RLS itself never
-- enforced it. Live-verified by this round's audit: a real CRP account
-- self-resolved and self-escalated-to-'urgent' her own filed ticket via a
-- direct RLS-scoped UPDATE — 1 row updated, matching the UI's own claim
-- about what should be impossible. Fixed by adding `member_id <> auth.uid()`
-- to the staff branch, mirroring the marketplace_orders precedent.
--
-- 2. [MEDIUM] `marketplace_products` had no server-side bound on `name`/
-- `description` length or `category` value — unlike every sibling table
-- (support_tickets.category is check-constrained; subject/description are
-- length-capped, migrations 0078/0093). The client (add_product_page.dart)
-- caps name at 100 chars, description at 500, and category to 5 fixed
-- chip values, but a direct REST insert bypasses all of it. Live-verified:
-- a 50,008-char name and a 200,000-char description inserted with no error.
-- Added as NOT VALID (per this project's established precedent, migration
-- 0122) so any pre-existing out-of-range row isn't retroactively rejected —
-- enforced for future writes only.
--
-- 3. [MEDIUM/LOW] `marketplace_reviews.comment` has the same unbounded gap
-- — client caps it at 300 chars (product_detail_page.dart), DB doesn't.
-- Same NOT VALID treatment.
--
-- 4. [MEDIUM] `place_marketplace_order()` had no per-buyer rate limit,
-- unlike every other mutating RPC/insert path in this schema (products
-- 10/hr, tickets 10/hr, messages 20/10min, announcements 10/hr, payments
-- 30/hr). Since payments are still mocked (no real settlement, per SRS
-- §3.11), a scripted caller could rapid-fire this RPC across every listed
-- product to drain every seller's stock to zero at no cost — a real,
-- currently-open DoS on the whole catalog. Unlike the earlier multi-row-
-- INSERT rate-limit bypass class, this RPC only ever inserts one order per
-- call (each call is its own statement), so a simple in-function count
-- check is sufficient here — no statement-level trigger needed.

drop policy if exists "support_tickets_update_staff_or_self_reopen" on public.support_tickets;

create policy "support_tickets_update_staff_or_self_reopen" on public.support_tickets
  for update using (
    (public.is_staff() and member_id <> auth.uid())
    or (member_id = auth.uid() and status in ('resolved', 'closed') and public.profile_is_active(member_id))
  )
  with check (
    (
      public.is_staff()
      and member_id <> auth.uid()
      and subject = (select f.subject from public.support_tickets_locked_fields(support_tickets.id) f)
      and description is not distinct from (select f.description from public.support_tickets_locked_fields(support_tickets.id) f)
      and created_at = (select f.created_at from public.support_tickets_locked_fields(support_tickets.id) f)
      and member_id = (select f.member_id from public.support_tickets_locked_fields(support_tickets.id) f)
      and category = (select f.category from public.support_tickets_locked_fields(support_tickets.id) f)
      and (
        resolved_by is not distinct from (select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f)
        or resolved_by = auth.uid()
      )
      and (
        resolved_at is not distinct from (select f.resolved_at from public.support_tickets_locked_fields(support_tickets.id) f)
        or resolved_by is distinct from (select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f)
      )
    )
    or (
      member_id = auth.uid()
      and public.profile_is_active(member_id)
      and status = 'open'
      and priority = (select f.priority from public.support_tickets_locked_fields(support_tickets.id) f)
      and subject = (select f.subject from public.support_tickets_locked_fields(support_tickets.id) f)
      and description is not distinct from (select f.description from public.support_tickets_locked_fields(support_tickets.id) f)
      and created_at = (select f.created_at from public.support_tickets_locked_fields(support_tickets.id) f)
      and member_id = (select f.member_id from public.support_tickets_locked_fields(support_tickets.id) f)
      and category = (select f.category from public.support_tickets_locked_fields(support_tickets.id) f)
      and resolved_by is not distinct from (select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f)
      and resolved_at is not distinct from (select f.resolved_at from public.support_tickets_locked_fields(support_tickets.id) f)
    )
  );

alter table public.marketplace_products
  add constraint marketplace_products_name_length_check check (char_length(name) <= 150) not valid;
alter table public.marketplace_products
  add constraint marketplace_products_description_length_check check (description is null or char_length(description) <= 1000) not valid;
alter table public.marketplace_products
  add constraint marketplace_products_category_check check (category is null or category in ('Handicrafts', 'Tailoring', 'Food', 'Agriculture', 'Other')) not valid;

alter table public.marketplace_reviews
  add constraint marketplace_reviews_comment_length_check check (comment is null or char_length(comment) <= 500) not valid;

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
