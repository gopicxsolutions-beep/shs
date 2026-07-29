-- Gap-hunt round 190 (iteration 18): fixes from this round's dogfooding
-- audit (2 more self-caught HIGH bugs, matching the by-now well-
-- established "is_staff()/leader branch left completely open" pattern
-- already fixed for loans/marketplace_orders/marketplace_products) plus
-- one confirmed HIGH finding from the Schemes/Training audit.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [HIGH, self-caught via dogfooding] savings_insert_self_leader_or_staff's
--    `is_staff()` branch had ZERO constraints beyond `profile_is_active` —
--    unlike the self/leader branch, which pins `status='pending'`,
--    `entry_date=CURRENT_DATE`, `created_at=now()`, and the correct
--    `shg_id`. A crp/clf/admin could insert a savings_entries row with
--    `status='verified'` directly (skipping the leader-verification
--    workflow entirely), an arbitrary `shg_id` that doesn't match the
--    member's real SHG (corrupting that SHG's totals/reports), and
--    fabricated `entry_date`/`created_at`. Fixed by requiring the staff
--    branch to match the same shape as the leader branch, just without the
--    `current_shg_id()` restriction (staff are platform-wide, per this
--    schema's established staff-scope model — matching how `is_staff()`
--    branches work everywhere else in this file's sibling policies).
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "savings_insert_self_leader_or_staff" on public.savings_entries;

create policy "savings_insert_self_leader_or_staff" on public.savings_entries
  for insert with check (
    status = 'pending'
    and entry_date = current_date
    and created_at = now()
    and (
      (member_id = auth.uid() and shg_id = public.current_shg_id())
      or (shg_id = public.current_shg_id() and public.current_role() = 'leader' and public.profile_shg_id(member_id) = shg_id and public.profile_is_active(member_id))
      or (public.is_staff() and public.profile_shg_id(member_id) = shg_id and public.profile_is_active(member_id))
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. [HIGH, self-caught via dogfooding] savings_update_leader_or_staff had
--    no `member_id <> auth.uid()` exclusion on the leader branch (`using`
--    or `with check`) — unlike `record_loan_payment`'s explicit "cannot
--    record a payment on your own loan" self-check. A leader could deposit
--    her own savings entry and then immediately self-verify it with no
--    second party ever reviewing it — the UI didn't even filter the
--    "Verify" button by row ownership, so this was directly clickable, not
--    just a REST-only exploit. Fixed by adding the same self-exclusion to
--    both the leader and staff branches (staff self-exclusion is defense-
--    in-depth for the edge case of a staff account that also happens to
--    have her own savings_entries row).
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "savings_update_leader_or_staff" on public.savings_entries;

create policy "savings_update_leader_or_staff" on public.savings_entries
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader' and member_id <> auth.uid())
    or (public.is_staff() and member_id <> auth.uid())
  ) with check (
    (public.is_staff() and member_id <> auth.uid())
    or (
      shg_id = public.current_shg_id()
      and public.current_role() = 'leader'
      and member_id <> auth.uid()
      and amount = (select f.amount from public.savings_entries_locked_fields(savings_entries.id) f)
      and member_id = (select f.member_id from public.savings_entries_locked_fields(savings_entries.id) f)
      and mode = (select f.mode from public.savings_entries_locked_fields(savings_entries.id) f)
      and frequency = (select f.frequency from public.savings_entries_locked_fields(savings_entries.id) f)
      and entry_date = (select f.entry_date from public.savings_entries_locked_fields(savings_entries.id) f)
      and created_at = (select f.created_at from public.savings_entries_locked_fields(savings_entries.id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. [MEDIUM, self-caught via dogfooding] 0096's anon-grant hygiene sweep
--    only ever revoked `anon, authenticated` explicitly — it never checked
--    for a pre-existing PUBLIC grant. `marketplace_reviews_pin_reviewer_
--    name()` (0069) was created before this schema's default-privilege
--    grant existed and carries its own direct `PUBLIC` ACL entry, which
--    0096 missed. Not exploitable in practice (a `returns trigger`
--    function can't be invoked outside trigger context, and PostgREST
--    excludes it from RPC), but closes the sweep's own stated goal for
--    real this time.
-- ─────────────────────────────────────────────────────────────────────────

revoke execute on function public.marketplace_reviews_pin_reviewer_name() from public;

-- ─────────────────────────────────────────────────────────────────────────
-- 4. [MEDIUM-HIGH, Schemes audit] scheme_applications_insert_self checked
--    `member_id = auth.uid()` but never `current_role() = 'member'` — a
--    crp/clf/admin account (which structurally has no `shg_id` and is not
--    an SHG member) could apply to any scheme lacking the "requires SHG
--    membership" checkbox (the default for every scheme, since
--    `scheme_eligibility_met()` short-circuits to `true` on an empty
--    criteria object). The application would then sit in the same shared
--    staff review queue, where a *different* staff account's self-decision
--    guard doesn't stop them approving a colleague for a benefit meant for
--    grassroots SHG members. Fixed by requiring `current_role() = 'member'`.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "scheme_applications_insert_self" on public.scheme_applications;

create policy "scheme_applications_insert_self" on public.scheme_applications
  for insert with check (
    member_id = auth.uid()
    and public.current_role() = 'member'
    and public.profile_is_active(member_id)
    and status = 'applied'
    and applied_on = current_date
    and exists (select 1 from public.schemes s where s.id = scheme_applications.scheme_id and (s.deadline is null or s.deadline >= current_date))
    and public.scheme_eligibility_met(scheme_id, member_id)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 5. [MEDIUM, Schemes audit, forward-looking defense-in-depth]
--    scheme_eligibility_met() silently ignored any eligibility_criteria
--    key it didn't recognize — unreachable today (the Dart model only ever
--    produces the 3 known keys), but a future criterion added to the model
--    without a matching SQL update would let a direct REST/RPC call bypass
--    it silently while the client-side gate still (correctly) blocks
--    members through the UI. Fails closed (denies eligibility) on any
--    unrecognized key, matching this same function's own existing
--    fail-closed precedent for an unrecognized/missing grade.
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.scheme_eligibility_met(p_scheme_id uuid, p_member_id uuid)
returns boolean
language plpgsql
stable security definer
set search_path = public
as $$
declare
  v_criteria jsonb;
  v_requires_membership boolean;
  v_min_age_months int;
  v_min_grade text;
  v_shg_id uuid;
  v_formation_date date;
  v_grade text;
  v_age_months int;
  -- Best -> worst, matching lib/models/scheme.dart's `_gradeOrder`.
  v_grade_rank constant jsonb := '{"A+":0,"A":1,"B+":2,"B":3,"C":4}'::jsonb;
  v_required_rank int;
  v_actual_rank int;
  v_unknown_key text;
begin
  select eligibility_criteria into v_criteria from public.schemes where id = p_scheme_id;
  if v_criteria is null or v_criteria = '{}'::jsonb then
    return true;
  end if;

  select k into v_unknown_key from jsonb_object_keys(v_criteria) k
    where k not in ('requires_shg_membership', 'min_shg_age_months', 'min_shg_grade')
    limit 1;
  if v_unknown_key is not null then
    return false;
  end if;

  v_requires_membership := coalesce((v_criteria->>'requires_shg_membership')::boolean, false);
  v_min_age_months := (v_criteria->>'min_shg_age_months')::int;
  v_min_grade := v_criteria->>'min_shg_grade';

  select p.shg_id into v_shg_id from public.profiles p where p.id = p_member_id;

  if v_requires_membership and v_shg_id is null then
    return false;
  end if;

  if v_min_age_months is not null then
    if v_shg_id is null then
      return false;
    end if;
    select s.formation_date into v_formation_date from public.shgs s where s.id = v_shg_id;
    if v_formation_date is null then
      return false;
    end if;
    v_age_months := extract(year from age(current_date, v_formation_date))::int * 12 + extract(month from age(current_date, v_formation_date))::int;
    if v_age_months < v_min_age_months then
      return false;
    end if;
  end if;

  if v_min_grade is not null then
    if v_shg_id is null then
      return false;
    end if;
    select s.grade into v_grade from public.shgs s where s.id = v_shg_id;
    v_required_rank := (v_grade_rank->>v_min_grade)::int;
    v_actual_rank := case when v_grade is null then null else (v_grade_rank->>v_grade)::int end;
    if v_required_rank is null or v_actual_rank is null or v_actual_rank > v_required_rank then
      return false;
    end if;
  end if;

  return true;
end;
$$;
