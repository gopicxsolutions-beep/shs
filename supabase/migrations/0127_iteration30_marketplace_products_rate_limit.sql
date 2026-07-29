-- Gap-hunt iteration 30: Marketplace full sweep, closing the "no rate
-- limit on listing a product" finding. Any authenticated user (member/
-- leader/staff, by design) could insert unlimited `marketplace_products`
-- rows with free-text name/description, visible to the entire platform —
-- unlike `support_tickets_insert_self`, which caps at 10/hour, nothing
-- bounded product listing at all. Added a per-row WITH CHECK limit
-- (consistent with every other rate-limited table in this schema) AND a
-- statement-level trigger from the start (this session's iteration 30
-- dogfooding pass just found and fixed the exact multi-row-INSERT bypass
-- that a WITH-CHECK-only limit has on 4 OTHER tables — see migration 0123
-- — so this one is built correctly from day one instead of needing the
-- same follow-up fix later).

drop policy if exists "marketplace_products_insert_seller_or_staff" on public.marketplace_products;

create policy "marketplace_products_insert_seller_or_staff" on public.marketplace_products
  for insert with check (
    (
      (seller_id = auth.uid() and public.profile_is_active(seller_id))
      or public.is_staff()
    )
    and (
      select count(*) from public.marketplace_products p
      where p.seller_id = auth.uid() and p.created_at > now() - interval '1 hour'
    ) < 10
  );

create or replace function public.marketplace_products_enforce_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from (select distinct seller_id from new_rows) g
    where (
      select count(*) from public.marketplace_products p
      where p.seller_id = g.seller_id and p.created_at > now() - interval '1 hour'
    ) > 10
  ) then
    raise exception 'too many products listed in the last hour';
  end if;
  return null;
end;
$$;

drop trigger if exists marketplace_products_rate_limit_trigger on public.marketplace_products;
create trigger marketplace_products_rate_limit_trigger
  after insert on public.marketplace_products
  referencing new table as new_rows
  for each statement
  execute function public.marketplace_products_enforce_rate_limit();
