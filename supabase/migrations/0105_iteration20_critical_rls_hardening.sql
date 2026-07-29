-- Gap-hunt iteration 20 (round 193): 4 parallel audits (dogfood round 192,
-- SHG Directory + Join Requests, Profile/Settings, Reports/Analytics)
-- converged on 26 unique confirmed findings. This migration closes every
-- RLS/backend gap among them.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [CRITICAL] `financial_ledger_update_staff` was bare `is_staff()` in
--    both USING and WITH CHECK — no self-exclusion, no column lock. Any
--    crp/clf/admin could PATCH any ledger row via direct REST and rewrite
--    shg_id/entry_type/debit/credit/balance/created_by/entry_date, forging
--    the audit ledger — including her own entries. Migration 0104 fixed
--    this exact table's DELETE policy but missed the UPDATE policy sitting
--    right next to it. No `.update()` call site exists in lib/ for this
--    table, so every column is locked (mirrors 0104's payments_update_staff
--    fix for the identical "not yet built, still open via direct REST" shape).
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.financial_ledger_locked_fields(p_id uuid)
returns table (shg_id uuid, entry_type text, description text, debit numeric, credit numeric, balance numeric, entry_date date, created_by uuid, created_at timestamptz)
language sql
stable security definer
set search_path = public
as $$
  select l.shg_id, l.entry_type, l.description, l.debit, l.credit, l.balance, l.entry_date, l.created_by, l.created_at
  from public.financial_ledger l
  where l.id = p_id and public.is_staff();
$$;

revoke all on function public.financial_ledger_locked_fields(uuid) from public, anon;
grant execute on function public.financial_ledger_locked_fields(uuid) to authenticated;

drop policy if exists "financial_ledger_update_staff" on public.financial_ledger;

create policy "financial_ledger_update_staff" on public.financial_ledger
  for update using (public.is_staff() and created_by <> auth.uid())
  with check (
    public.is_staff()
    and created_by <> auth.uid()
    and shg_id = (select f.shg_id from public.financial_ledger_locked_fields(financial_ledger.id) f)
    and entry_type = (select f.entry_type from public.financial_ledger_locked_fields(financial_ledger.id) f)
    and description is not distinct from (select f.description from public.financial_ledger_locked_fields(financial_ledger.id) f)
    and debit = (select f.debit from public.financial_ledger_locked_fields(financial_ledger.id) f)
    and credit = (select f.credit from public.financial_ledger_locked_fields(financial_ledger.id) f)
    and balance = (select f.balance from public.financial_ledger_locked_fields(financial_ledger.id) f)
    and entry_date = (select f.entry_date from public.financial_ledger_locked_fields(financial_ledger.id) f)
    and created_by = (select f.created_by from public.financial_ledger_locked_fields(financial_ledger.id) f)
    and created_at = (select f.created_at from public.financial_ledger_locked_fields(financial_ledger.id) f)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2 & 3. [HIGH] `marketplace_reviews_moderate_staff` had `with_check = null`
--    — Postgres reuses USING as the check when WITH CHECK is omitted, so
--    this was fully unrestricted: any staff could rewrite rating/comment/
--    product_id/reviewer_id on ANY review, including one she wrote herself
--    before promotion. `marketplace_reviews_delete_staff` had the same
--    self-service gap for deletion. Fixed with self-exclusion on both plus
--    a column lock on UPDATE (product_id/reviewer_id/reviewer_name/
--    created_at frozen; rating/comment stay staff-editable — that's the
--    actual moderation action).
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.marketplace_reviews_locked_fields(p_id uuid)
returns table (product_id uuid, reviewer_id uuid, reviewer_name text, created_at timestamptz)
language sql
stable security definer
set search_path = public
as $$
  select r.product_id, r.reviewer_id, r.reviewer_name, r.created_at
  from public.marketplace_reviews r
  where r.id = p_id and public.is_staff();
$$;

revoke all on function public.marketplace_reviews_locked_fields(uuid) from public, anon;
grant execute on function public.marketplace_reviews_locked_fields(uuid) to authenticated;

drop policy if exists "marketplace_reviews_moderate_staff" on public.marketplace_reviews;

create policy "marketplace_reviews_moderate_staff" on public.marketplace_reviews
  for update using (public.is_staff() and reviewer_id <> auth.uid())
  with check (
    public.is_staff()
    and reviewer_id <> auth.uid()
    and product_id = (select f.product_id from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
    and reviewer_id = (select f.reviewer_id from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
    and reviewer_name = (select f.reviewer_name from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
    and created_at = (select f.created_at from public.marketplace_reviews_locked_fields(marketplace_reviews.id) f)
  );

drop policy if exists "marketplace_reviews_delete_staff" on public.marketplace_reviews;
create policy "marketplace_reviews_delete_staff" on public.marketplace_reviews
  for delete using (public.is_staff() and reviewer_id <> auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- 4. [HIGH] `livelihood_update_self_leader_or_staff`'s WITH CHECK had a bare
--    `is_staff() OR (...)` top-level disjunct — when true, none of the
--    transition-limit (`abs(position diff) <= 1`) or revenue-lock-once-
--    completed restrictions the member/leader branch enforces applied to a
--    staff account editing HER OWN historical activity. A promoted member
--    could freely rewrite her own status/revenue via her new staff role.
--    Fixed the same way this session's other self-dealing gaps were closed:
--    staff editing SOMEONE ELSE's row stays fully unrestricted (genuine
--    oversight capability, unchanged); staff editing their OWN row now
--    falls through to the same restricted branch a member/leader must obey.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "livelihood_update_self_leader_or_staff" on public.livelihood_activities;

create policy "livelihood_update_self_leader_or_staff" on public.livelihood_activities
  for update using (
    member_id = auth.uid()
    or (shg_id = public.current_shg_id() and public.current_role() = 'leader')
    or public.is_staff()
  )
  with check (
    (public.is_staff() and member_id <> auth.uid())
    or (
      (member_id = auth.uid() or (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff())
      and shg_id = (select f.shg_id from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and member_id = (select f.member_id from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and activity_type = (select f.activity_type from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and description is not distinct from (select f.description from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and investment is not distinct from (select f.investment from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and created_at = (select f.created_at from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      and abs(
        array_position(array['planned','active','completed'], status)
        - array_position(array['planned','active','completed'], (select f.status from public.livelihood_activities_locked_fields(livelihood_activities.id) f))
      ) <= 1
      and (
        (select f.status from public.livelihood_activities_locked_fields(livelihood_activities.id) f) <> 'completed'
        or revenue = (select f.revenue from public.livelihood_activities_locked_fields(livelihood_activities.id) f)
      )
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 5 & 6. [MEDIUM] `livelihood_delete_staff` and `marketplace_products_
--    delete_staff` were bare `is_staff()` despite both tables carrying an
--    owner column (`member_id`, `seller_id`) — same recurring "staff branch
--    left wide open" shape, now closed with self-exclusion.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "livelihood_delete_staff" on public.livelihood_activities;
create policy "livelihood_delete_staff" on public.livelihood_activities
  for delete using (public.is_staff() and member_id <> auth.uid());

drop policy if exists "marketplace_products_delete_staff" on public.marketplace_products;
create policy "marketplace_products_delete_staff" on public.marketplace_products
  for delete using (public.is_staff() and seller_id <> auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- 7. [LOW] `support_tickets_update_staff_or_self_reopen`'s staff branch had
--    no self-exclusion — a staff account that filed a ticket pre-promotion
--    could resolve/reassign her own complaint unchecked. The self-reopen
--    branch already covers legitimate self-service (any role, ticket in
--    resolved/closed status), so restricting the staff branch doesn't
--    remove any real capability.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "support_tickets_update_staff_or_self_reopen" on public.support_tickets;

create policy "support_tickets_update_staff_or_self_reopen" on public.support_tickets
  for update using (
    (public.is_staff() and member_id <> auth.uid())
    or (member_id = auth.uid() and status = any(array['resolved','closed']) and public.profile_is_active(member_id))
  )
  with check (
    (
      public.is_staff()
      and member_id <> auth.uid()
      and subject = (select f.subject from public.support_tickets_locked_fields(support_tickets.id) f)
      and description is not distinct from (select f.description from public.support_tickets_locked_fields(support_tickets.id) f)
      and created_at = (select f.created_at from public.support_tickets_locked_fields(support_tickets.id) f)
      and member_id = (select f.member_id from public.support_tickets_locked_fields(support_tickets.id) f)
      and (resolved_by is not distinct from (select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f) or resolved_by = auth.uid())
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
      and resolved_by is not distinct from (select f.resolved_by from public.support_tickets_locked_fields(support_tickets.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 8 & 9. [MEDIUM] SHG Join Requests deactivated-member handling: (a)
--    `shg_join_requests_insert_self` had no `profile_is_active` gate — a
--    deactivated member could still file a fresh join request directly via
--    REST; (b) `approve_shg_join_request` never checked the REQUESTER's
--    `is_active`, so a leader/staff could approve a deactivated member into
--    an SHG, polluting the roster.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "shg_join_requests_insert_self" on public.shg_join_requests;

create policy "shg_join_requests_insert_self" on public.shg_join_requests
  for insert with check (
    member_id = auth.uid()
    and public.profile_is_active(member_id)
    and status = 'pending'
    and requested_at = now()
    and decided_at is null
    and decided_by is null
    and not exists (select 1 from public.profiles p where p.id = shg_join_requests.member_id and p.shg_id is not null)
  );

create or replace function public.approve_shg_join_request(p_request_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = 'public'
as $function$
declare
  v_request record;
  v_member_role text;
begin
  select * into v_request from public.shg_join_requests where id = p_request_id for update;
  if v_request is null then
    raise exception 'join request not found';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'join request already decided (current status: %)', v_request.status;
  end if;

  if not (
    (public.current_role() = 'leader' and public.current_shg_id() = v_request.shg_id)
    or public.is_staff()
  ) then
    raise exception 'not authorized to decide this request';
  end if;

  if p_approve and not public.profile_is_active(v_request.member_id) then
    raise exception 'requester account is deactivated';
  end if;

  if p_approve then
    select role into v_member_role from public.profiles where id = v_request.member_id;
    update public.profiles
      set shg_id = v_request.shg_id,
          role = case when v_member_role = 'leader' then 'member' else v_member_role end
      where id = v_request.member_id;
    update public.shg_join_requests set status = 'approved', decided_at = now(), decided_by = auth.uid() where id = p_request_id;
  else
    update public.shg_join_requests set status = 'rejected', decided_at = now(), decided_by = auth.uid() where id = p_request_id;
  end if;
end;
$function$;

revoke all on function public.approve_shg_join_request(uuid, boolean) from public, anon;
grant execute on function public.approve_shg_join_request(uuid, boolean) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 10. [MEDIUM] `profiles_update_self_or_admin`'s self branch required
--     `shg_id is not distinct from current_shg_id()` and a role check built
--     on `current_role()`/`current_shg_id()` — both of which already return
--     NULL for any deactivated caller, blocking most deactivated self-edits.
--     But a member/leader deactivated BEFORE SHG approval (shg_id already
--     null) slipped through: `current_shg_id() IS NULL` and
--     `shg_id is not distinct from NULL` both evaluate true regardless of
--     deactivation, so the row update still succeeded — a deactivated,
--     never-approved account could still rewrite her own name/village via
--     direct REST, contradicting the "blanket lockout" this policy's own
--     0083 comment describes. Fixed with an explicit `is_active` assertion
--     on the row itself (not routed through the helpers, since those are
--     exactly what the deactivated caller's NULL-return already defeats
--     here) — safe because `is_active` is already locked to its unchanged
--     value by the existing profiles_locked_fields check just below.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "profiles_update_self_or_admin" on public.profiles;

create policy "profiles_update_self_or_admin" on public.profiles
  for update using (id = auth.uid() or public.current_role() = 'admin')
  with check (
    public.current_role() = 'admin'
    or (
      id = auth.uid()
      and is_active
      and shg_id is not distinct from public.current_shg_id()
      and (role = public.current_role() or (role = any(array['member','leader']) and public.current_shg_id() is null))
      and mobile is not distinct from (select f.mobile from public.profiles_locked_fields(profiles.id) f)
      and created_at is not distinct from (select f.created_at from public.profiles_locked_fields(profiles.id) f)
      and is_active is not distinct from (select f.is_active from public.profiles_locked_fields(profiles.id) f)
      and deactivated_at is not distinct from (select f.deactivated_at from public.profiles_locked_fields(profiles.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 11. [HIGH] Mandal/District, collected on the onboarding form since v1,
--     were never persisted anywhere — `profiles` had no such columns, and
--     `AppState.completeProfileSetup`'s live branch never forwarded them to
--     `upsertMyProfile`. A member filled these in, tapped Continue, got no
--     error, and the data silently vanished. Adding nullable columns here;
--     neither `profiles_insert_self` nor `profiles_update_self_or_admin`
--     reference them, so both existing policies already permit self-service
--     writes to these two columns with no policy change needed.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.profiles add column if not exists mandal text;
alter table public.profiles add column if not exists district text;

-- ─────────────────────────────────────────────────────────────────────────
-- 12. [LOW-MEDIUM] `ShgJoinRequestRepository.submit()` did a non-atomic
--     DELETE-then-INSERT (two separate network calls) to replace a pending
--     request — an interruption between them could orphan a member with
--     zero pending rows. Wrapping both statements in one SQL function makes
--     them atomic (same implicit single-transaction guarantee every plpgsql
--     function body already gets) — SECURITY INVOKER (the default), so RLS
--     still applies exactly as it did for the two separate client calls;
--     this is a transaction-atomicity fix, not a privilege change.
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.submit_shg_join_request(p_shg_id uuid)
returns void
language plpgsql
set search_path = 'public'
as $function$
begin
  delete from public.shg_join_requests where member_id = auth.uid() and status = 'pending';
  insert into public.shg_join_requests (member_id, shg_id) values (auth.uid(), p_shg_id);
end;
$function$;

revoke all on function public.submit_shg_join_request(uuid) from public, anon;
grant execute on function public.submit_shg_join_request(uuid) to authenticated;
