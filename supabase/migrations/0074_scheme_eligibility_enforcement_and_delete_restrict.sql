-- Two gaps found in a fresh audit of scheme catalog management:
--
-- 1. Structured eligibility criteria (`schemes.eligibility_criteria`, 0040)
--    is evaluated ONLY by the client-side rules engine
--    (`evaluateSchemeEligibility`, lib/models/scheme.dart) on the standalone
--    `SchemeEligibilityPage` "checker" screen — which has no wiring back
--    into the actual Apply flow. `SchemeDetailPage`'s Apply button gates
--    only on the application deadline, never eligibility, so an ineligible
--    member isn't even blocked through the normal in-app UI, let alone a
--    direct REST call. `scheme_applications_insert_self` (0030) and
--    `decide_scheme_application` (0029) check status/deadline only — a
--    member with no SHG, or an SHG below a scheme's declared minimum grade/
--    age, can apply and be approved for a scheme this app's own catalog
--    says they don't qualify for. Fixed with a `security definer` function
--    re-deriving the same three checks `evaluateSchemeEligibility` computes
--    client-side, wired into the INSERT policy's `with check` — the actual
--    trust boundary, not just the UI affordance (the client-side gate is a
--    separate, non-security fix in lib/pages/schemes/scheme_detail_page.dart).
--    A scheme with no structured criteria (`eligibility_criteria = '{}'`)
--    is unaffected, same as the client-side engine's own `isEmpty` case.
--
-- 2. `scheme_applications.scheme_id` was `on delete cascade`
--    (0001_init_schema.sql) — deleting a scheme from the admin catalog
--    silently destroys every application ever filed against it, including
--    already-approved/rejected decisions with `decided_by`/`decided_at`
--    attribution (0029). Same blast-radius shape already fixed for loans
--    (0063) and financial_ledger (0072) — same fix here.

create or replace function public.scheme_eligibility_met(p_scheme_id uuid, p_member_id uuid)
returns boolean
language plpgsql
security definer
stable
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
begin
  select eligibility_criteria into v_criteria from public.schemes where id = p_scheme_id;
  if v_criteria is null or v_criteria = '{}'::jsonb then
    return true;
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
    -- Fail-safe: an unrecognized/missing required or actual grade can never
    -- be confirmed met, mirrors `evaluateSchemeEligibility`'s own
    -- `requiredIdx != -1 && actualIdx != -1` guard.
    if v_required_rank is null or v_actual_rank is null or v_actual_rank > v_required_rank then
      return false;
    end if;
  end if;

  return true;
end;
$$;

revoke all on function public.scheme_eligibility_met(uuid, uuid) from public;
grant execute on function public.scheme_eligibility_met(uuid, uuid) to authenticated;

drop policy if exists "scheme_applications_insert_self" on public.scheme_applications;

create policy "scheme_applications_insert_self" on public.scheme_applications
  for insert with check (
    member_id = auth.uid()
    and status = 'applied'
    and applied_on = current_date
    and exists (
      select 1 from public.schemes s
      where s.id = scheme_id
        and (s.deadline is null or s.deadline >= current_date)
    )
    and public.scheme_eligibility_met(scheme_id, member_id)
  );

alter table public.scheme_applications drop constraint scheme_applications_scheme_id_fkey;
alter table public.scheme_applications add constraint scheme_applications_scheme_id_fkey foreign key (scheme_id) references public.schemes (id) on delete restrict;
