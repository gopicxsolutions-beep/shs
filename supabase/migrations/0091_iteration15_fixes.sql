-- Gap-hunt round 187 (iteration 15): four fresh audits (dogfooding round
-- 186's own features, AI Advisor modules, Admin/Profile/Notifications,
-- Marketplace seller tools/Reports export). The dogfooding audit caught a
-- real bug in round 186's own migration (0090): its comment claimed the
-- meeting_attendance INSERT self-branch already required same-day
-- attendance — it did not, and 0090 never added that check despite fixing
-- the sibling UPDATE policy. This migration fixes that first, then closes
-- everything else this round's audits found.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [Correcting round 186's own false claim] meeting_attendance INSERT
--    self-branch: `MeetingRepository.markAttendance()` upserts, so a
--    member with no existing attendance row for a given past meeting (the
--    common case for anyone never explicitly toggled by a leader —
--    `fetchAttendance()` defaults an untouched member to `present: false`
--    client-side, no row exists) could `POST` a fabricated "present" row
--    for ANY past, non-cancelled meeting in her own SHG via direct REST,
--    exactly the backdating gap 0090's UPDATE-side fix was supposed to
--    close but never actually closed on the INSERT side.
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
          and m.meeting_date = current_date
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

-- ─────────────────────────────────────────────────────────────────────────
-- 2. Two more missed tables in the `profile_is_active()` sweep — the 4th
--    and 5th rounds in a row this exact pattern has surfaced one more
--    table each time: `course_progress_write_self_or_staff` (`is_staff()`
--    branch has zero restriction at all, and the self branch never checked
--    the caller's own active status) and `support_messages_insert_related`
--    (a deactivated member could still post new messages onto her own
--    existing ticket).
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "course_progress_write_self_or_staff" on public.course_progress;

create policy "course_progress_write_self_or_staff" on public.course_progress
  for all using (
    member_id = auth.uid() or public.is_staff()
  ) with check (
    (public.is_staff() and public.profile_is_active(member_id))
    or (
      member_id = auth.uid()
      and public.profile_is_active(member_id)
      and certified = coalesce((select f.certified from public.course_progress_locked_fields(course_id, member_id) f), false)
      and completed_on is not distinct from (select f.completed_on from public.course_progress_locked_fields(course_id, member_id) f)
    )
  );

drop policy if exists "support_messages_insert_related" on public.support_messages;

create policy "support_messages_insert_related" on public.support_messages
  for insert with check (
    sender_id = auth.uid()
    and public.profile_is_active(sender_id)
    and exists (
      select 1 from public.support_tickets t
      where t.id = support_messages.ticket_id and (t.member_id = auth.uid() or public.is_staff())
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. place_marketplace_order (0057): `security definer`, the only path to
--    create a real order — never got the `profile_is_active()` check every
--    other self-action RPC/policy did across rounds 185-186. A deactivated
--    member's still-valid session could keep placing real orders,
--    decrementing a real seller's stock indefinitely. Checked before the
--    stock decrement so a blocked call never touches a seller's inventory.
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
begin
  select name into v_buyer_name from public.profiles where id = auth.uid();
  if v_buyer_name is null then
    raise exception 'No profile found for the current user.';
  end if;
  if not public.profile_is_active(auth.uid()) then
    raise exception 'your account has been deactivated';
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

-- ─────────────────────────────────────────────────────────────────────────
-- 4. marketplace_products_update_seller_or_staff (0039): `with check` was
--    literally `seller_id = auth.uid() or is_staff()` — no column lock at
--    all. The seller branch is incidentally self-limiting on `seller_id`
--    (changing it away from her own id fails that same condition unless
--    she's also staff), but the `is_staff()` branch had zero restriction
--    on anything, including `seller_id` and `created_at` — any crp/clf/
--    admin account could hijack a listing's ownership attribution or
--    fabricate its creation date via direct REST. No UI needs this (no
--    edit-listing UI exists at all yet, confirmed by this round's audit),
--    so closing it costs no functionality.
--
--    Also adds the one monetary-cap outlier this round's audit found:
--    `marketplace_products.price` never got the ₹10,00,000 fat-finger cap
--    every sibling monetary column already has.
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.marketplace_products_locked_fields(p_id uuid)
returns table (seller_id uuid, created_at timestamptz)
language sql
security definer
stable
set search_path = public
as $$
  select p.seller_id, p.created_at
  from public.marketplace_products p
  where p.id = p_id
    and (p.seller_id = auth.uid() or public.is_staff());
$$;

revoke all on function public.marketplace_products_locked_fields(uuid) from public;
grant execute on function public.marketplace_products_locked_fields(uuid) to authenticated;

drop policy if exists "marketplace_products_update_seller_or_staff" on public.marketplace_products;

create policy "marketplace_products_update_seller_or_staff" on public.marketplace_products
  for update using (seller_id = auth.uid() or public.is_staff())
  with check (
    (seller_id = auth.uid() or public.is_staff())
    and seller_id = (select f.seller_id from public.marketplace_products_locked_fields(marketplace_products.id) f)
    and created_at = (select f.created_at from public.marketplace_products_locked_fields(marketplace_products.id) f)
  );

alter table public.marketplace_products add constraint marketplace_products_price_cap check (price <= 1000000);

-- ─────────────────────────────────────────────────────────────────────────
-- 5. training_courses -> course_progress: still `on delete cascade` — the
--    identical shape already fixed with `on delete restrict` for loans
--    (0063), financial_ledger (0072), scheme_applications (0074), and
--    marketplace_orders/marketplace_reviews (0075), never extended to
--    Training. Deleting a course (reachable by crp/clf, not just admin)
--    silently destroys every member's earned certification/progress
--    history with only a generic confirm dialog that never mentions this.
--    `quiz_questions`/`quiz_attempt_counters` deliberately stay `cascade`
--    — deleting a course's own question bank/rate-limit rows alongside it
--    is expected, unlike erasing a member's real certification record.
--    `AdminTrainingCoursesPage._deleteCourse()` already has a generic
--    `catch (_)` showing a friendly error message, so a course with real
--    progress attached now fails loudly with existing UI, not a crash or
--    raw Postgres error.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.course_progress drop constraint course_progress_course_id_fkey;
alter table public.course_progress add constraint course_progress_course_id_fkey foreign key (course_id) references public.training_courses (id) on delete restrict;

-- ─────────────────────────────────────────────────────────────────────────
-- 6. Last-admin-lockout guards (0084/0085) had an unresolved TOCTOU race:
--    neither `select count(*) ... where role='admin' and is_active` ever
--    locked the rows it counted. Two concurrent transactions each acting
--    on a different one of exactly 2 remaining active admins (e.g. two
--    admin sessions demoting/deactivating each other at the same moment)
--    could each see the other as still active under READ COMMITTED, both
--    pass the check, both commit — zero active admins, exactly the state
--    these triggers exist to make impossible. Same `for update` pattern
--    this codebase already uses for `record_loan_payment`/`approve_loan`,
--    just never applied here.
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.guard_last_admin_deactivation()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_other_active_admins int;
begin
  if old.role = 'admin' and old.is_active and (new.role <> 'admin' or not new.is_active) then
    select count(*) into v_other_active_admins
    from public.profiles
    where role = 'admin' and is_active and id <> old.id
    for update;

    if v_other_active_admins = 0 then
      raise exception 'cannot remove the last active admin account (deactivating, or changing role away from admin)';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.guard_last_admin_delete()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_other_active_admins int;
begin
  if old.role = 'admin' and old.is_active then
    select count(*) into v_other_active_admins
    from public.profiles
    where role = 'admin' and is_active and id <> old.id
    for update;

    if v_other_active_admins = 0 then
      raise exception 'cannot delete the last active admin account';
    end if;
  end if;
  return old;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 7. Account deactivation and SHG (re)assignment were invisible to the
--    audit trail, unlike role changes — `AdminRepository.setActive()`/
--    `assignShg()` write straight to `profiles.is_active`/`shg_id` with no
--    corresponding trigger, despite deactivation being arguably the single
--    most consequential thing the admin users page does. Extends the
--    existing role-change trigger (0082) to also log these two, as
--    separate action types (existing `role_change` consumers/rendering
--    untouched).
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.audit_profile_role_change()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.role is distinct from old.role then
    insert into public.audit_log (actor_id, action, entity, entity_id, meta)
    values (auth.uid(), 'role_change', 'profiles', new.id, jsonb_build_object('old_role', old.role, 'new_role', new.role));
  end if;
  if new.is_active is distinct from old.is_active then
    insert into public.audit_log (actor_id, action, entity, entity_id, meta)
    values (auth.uid(), 'deactivation', 'profiles', new.id, jsonb_build_object('old_is_active', old.is_active, 'new_is_active', new.is_active));
  end if;
  if new.shg_id is distinct from old.shg_id then
    insert into public.audit_log (actor_id, action, entity, entity_id, meta)
    values (auth.uid(), 'shg_reassignment', 'profiles', new.id, jsonb_build_object('old_shg_id', old.shg_id, 'new_shg_id', new.shg_id));
  end if;
  return new;
end;
$$;
