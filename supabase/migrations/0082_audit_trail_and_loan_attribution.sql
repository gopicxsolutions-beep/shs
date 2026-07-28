-- Gap-hunt iteration 9 finding: `public.audit_log` (0001) has RLS and is
-- documented in ARCHITECTURE.md as the "admin/privileged-action audit
-- trail", but nothing anywhere ever inserts into it -- every staff
-- privileged action (role grants, SHG grade edits, loan decisions,
-- livelihood staff corrections) is silently unlogged. Loans specifically
-- have no decided_by/decided_at at all, unlike scheme_applications (0050),
-- shg_join_requests (0004), and support_tickets (0052), which all already
-- attribute their staff decision to a specific account and timestamp.
--
-- Separately: `shgs_update_leader_or_staff` (0013) lets ANY is_staff()
-- account (crp/clf/admin) rewrite ANY SHG's grade/clf/vo/name/village/
-- district unconditionally -- but grep confirms the only app-code path that
-- ever calls `ShgRepository.updateShg()` is AdminShgsPage's Edit dialog,
-- gated `isAdmin` at the UI layer. The RLS layer never matched that
-- UI-implied Admin-only scope, so a CRP/CLF account could bypass the UI
-- entirely via a direct REST PATCH and rewrite another federation's SHG
-- grade/affiliation -- exactly the "client-side check is UX only" gap
-- CLAUDE.md warns about. Tightened to admin-only; the leader branch (still
-- unused by any current UI, per 0013's own comment) is untouched.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. loans: decided_by/decided_at attribution, wired into the existing
--    lock-then-verify-then-transition RPCs (0029) so no separate race
--    window is introduced.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.loans add column if not exists decided_by uuid references public.profiles (id);
alter table public.loans add column if not exists decided_at timestamptz;

create or replace function public.approve_loan(p_loan_id uuid, p_emi numeric, p_next_due_date date)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_status text;
begin
  if p_emi is null or p_emi <= 0 then
    raise exception 'emi must be positive';
  end if;

  select status into v_status from public.loans where id = p_loan_id for update;

  if v_status is null then
    raise exception 'loan not found';
  end if;
  if v_status <> 'pending' then
    raise exception 'loan is no longer pending (current status: %)', v_status;
  end if;

  update public.loans
    set status = 'active',
        disbursed_on = current_date,
        emi = p_emi,
        next_due_date = p_next_due_date,
        decided_by = auth.uid(),
        decided_at = now()
    where id = p_loan_id;

  if not found then
    raise exception 'not authorized to update this loan, or loan not found';
  end if;
end;
$$;

create or replace function public.reject_loan(p_loan_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_status text;
begin
  select status into v_status from public.loans where id = p_loan_id for update;

  if v_status is null then
    raise exception 'loan not found';
  end if;
  if v_status <> 'pending' then
    raise exception 'loan is no longer pending (current status: %)', v_status;
  end if;

  update public.loans
    set status = 'rejected', decided_by = auth.uid(), decided_at = now()
    where id = p_loan_id;

  if not found then
    raise exception 'not authorized to update this loan, or loan not found';
  end if;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. shgs: updated_at (never existed on this table, unlike every other
--    mutable table since 0006) + tighten the staff bypass to admin-only.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.shgs add column if not exists updated_at timestamptz not null default now();

drop trigger if exists shgs_set_updated_at on public.shgs;
create trigger shgs_set_updated_at before update on public.shgs for each row execute function public.set_updated_at();

drop policy if exists "shgs_update_leader_or_staff" on public.shgs;

create policy "shgs_update_leader_or_staff" on public.shgs
  for update using (
    (id = public.current_shg_id() and public.current_role() = 'leader') or public.current_role() = 'admin'
  )
  with check (
    public.current_role() = 'admin'
    or (
      id = public.current_shg_id()
      and public.current_role() = 'leader'
      and grade is not distinct from (select r.grade from public.shgs_current_row(id) r)
      and clf is not distinct from (select r.clf from public.shgs_current_row(id) r)
      and vo is not distinct from (select r.vo from public.shgs_current_row(id) r)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. audit_log: real triggers for the four most privileged/sensitive
--    mutations. `audit_log_insert_self` (0002) only requires actor_id =
--    auth.uid(), which auth.uid() satisfies regardless of definer/invoker,
--    so these run as plain invoker-rights triggers -- no elevated privilege
--    needed just to write an audit row.
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
  return new;
end;
$$;

drop trigger if exists audit_profiles_role_change on public.profiles;
create trigger audit_profiles_role_change
  after update on public.profiles
  for each row execute function public.audit_profile_role_change();

create or replace function public.audit_shg_grade_change()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.grade is distinct from old.grade or new.clf is distinct from old.clf or new.vo is distinct from old.vo then
    insert into public.audit_log (actor_id, action, entity, entity_id, meta)
    values (auth.uid(), 'shg_grade_change', 'shgs', new.id, jsonb_build_object(
      'old_grade', old.grade, 'new_grade', new.grade,
      'old_clf', old.clf, 'new_clf', new.clf,
      'old_vo', old.vo, 'new_vo', new.vo
    ));
  end if;
  return new;
end;
$$;

drop trigger if exists audit_shgs_grade_change on public.shgs;
create trigger audit_shgs_grade_change
  after update on public.shgs
  for each row execute function public.audit_shg_grade_change();

create or replace function public.audit_livelihood_staff_override()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if public.is_staff() and (new.status is distinct from old.status or new.revenue is distinct from old.revenue) then
    insert into public.audit_log (actor_id, action, entity, entity_id, meta)
    values (auth.uid(), 'livelihood_staff_override', 'livelihood_activities', new.id, jsonb_build_object(
      'old_status', old.status, 'new_status', new.status,
      'old_revenue', old.revenue, 'new_revenue', new.revenue
    ));
  end if;
  return new;
end;
$$;

drop trigger if exists audit_livelihood_staff_override on public.livelihood_activities;
create trigger audit_livelihood_staff_override
  after update on public.livelihood_activities
  for each row execute function public.audit_livelihood_staff_override();

create or replace function public.audit_loan_decision()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if old.status = 'pending' and new.status in ('active', 'rejected') then
    insert into public.audit_log (actor_id, action, entity, entity_id, meta)
    values (auth.uid(), 'loan_decision', 'loans', new.id, jsonb_build_object('decision', new.status, 'emi', new.emi));
  end if;
  return new;
end;
$$;

drop trigger if exists audit_loans_decision on public.loans;
create trigger audit_loans_decision
  after update on public.loans
  for each row execute function public.audit_loan_decision();
