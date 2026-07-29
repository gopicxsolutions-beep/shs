-- Gap-hunt iteration 30 (dogfooding pass): closes a systemic bypass in
-- EVERY row-count-based rate limit in this schema — not just the one just
-- added for `payments` in migration 0120.
--
-- Root cause: a `WITH CHECK` clause like `(select count(*) from t where ...)
-- < N` is evaluated PER ROW being inserted, against each row's own
-- statement snapshot — rows inserted by the SAME multi-row INSERT are not
-- visible to each other's subquery (they share one command id under MVCC).
-- Live-verified (gap-hunt iteration 30's dogfooding pass): a single
-- `INSERT ... SELECT ... FROM generate_series(1,40)` against `payments`
-- inserted all 40 rows in one statement, completely ignoring the `< 30`
-- per-hour limit just added in migration 0120 — and PostgREST (what the
-- Supabase client SDK uses) accepts a JSON ARRAY body on a single POST,
-- executing exactly this kind of multi-row INSERT. No raw SQL access is
-- needed to exploit this — a single batched REST call does it. The same
-- shape is used by THREE other tables' insert policies
-- (`support_tickets_insert_self`, `announcements_insert_self_or_staff`,
-- `support_messages_insert_related`) — all four share this exact bypass,
-- not just payments.
--
-- Fix: a `WITH CHECK` alone cannot see sibling rows in the same statement,
-- so the limit is moved to an `AFTER INSERT ... FOR EACH STATEMENT` trigger
-- using a transition table (`REFERENCING NEW TABLE`). A statement-level
-- trigger fires once per INSERT statement, after ALL of its rows are
-- already visible in the base table within the same transaction — so
-- counting the base table now correctly includes the whole batch, closing
-- the gap regardless of how many rows one statement inserts. The original
-- per-row `WITH CHECK` limits are left in place too (defense in depth for
-- the single-row case, and they still block a member who's already over
-- the limit from a compliant client without needing the trigger to fire).

create or replace function public.payments_enforce_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from (select distinct member_id from new_rows) g
    where (
      select count(*) from public.payments p
      where p.member_id = g.member_id and p.created_at > now() - interval '1 hour'
    ) > 30
  ) then
    raise exception 'too many payments in the last hour';
  end if;
  return null;
end;
$$;

drop trigger if exists payments_rate_limit_trigger on public.payments;
create trigger payments_rate_limit_trigger
  after insert on public.payments
  referencing new table as new_rows
  for each statement
  execute function public.payments_enforce_rate_limit();

create or replace function public.support_tickets_enforce_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from (select distinct member_id from new_rows) g
    where (
      select count(*) from public.support_tickets t
      where t.member_id = g.member_id and t.created_at > now() - interval '1 hour'
    ) > 10
  ) then
    raise exception 'too many support tickets in the last hour';
  end if;
  return null;
end;
$$;

drop trigger if exists support_tickets_rate_limit_trigger on public.support_tickets;
create trigger support_tickets_rate_limit_trigger
  after insert on public.support_tickets
  referencing new table as new_rows
  for each statement
  execute function public.support_tickets_enforce_rate_limit();

create or replace function public.announcements_enforce_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from (select distinct created_by from new_rows) g
    where (
      select count(*) from public.announcements a
      where a.created_by = g.created_by and a.created_at > now() - interval '1 hour'
    ) > 10
  ) then
    raise exception 'too many announcements in the last hour';
  end if;
  return null;
end;
$$;

drop trigger if exists announcements_rate_limit_trigger on public.announcements;
create trigger announcements_rate_limit_trigger
  after insert on public.announcements
  referencing new table as new_rows
  for each statement
  execute function public.announcements_enforce_rate_limit();

create or replace function public.support_messages_enforce_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from (select distinct sender_id from new_rows) g
    where (
      select count(*) from public.support_messages m
      where m.sender_id = g.sender_id and m.created_at > now() - interval '10 minutes'
    ) > 20
  ) then
    raise exception 'too many support messages in the last 10 minutes';
  end if;
  return null;
end;
$$;

drop trigger if exists support_messages_rate_limit_trigger on public.support_messages;
create trigger support_messages_rate_limit_trigger
  after insert on public.support_messages
  referencing new table as new_rows
  for each statement
  execute function public.support_messages_enforce_rate_limit();
