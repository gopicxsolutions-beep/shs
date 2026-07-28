-- Gap-hunt round 185 (iteration 13), CRITICAL finding: `loans_update_leader_
-- or_staff` (last redefined in 0023) only ever locked `member_id`/`amount`/
-- `purpose`/`tenure_months`/`created_at`. Every state-machine column —
-- `status`, `outstanding`, `emi`, `disbursed_on`, `next_due_date`,
-- `decided_by`, `decided_at` — was left completely open on the theory that
-- "real approval/payment flows legitimately rewrite these" (0023's own
-- comment). True, but that theory only holds if every write to those
-- columns actually goes through `approve_loan`/`reject_loan`/
-- `record_loan_payment` (0029/0073/0082) — nothing at the RLS layer ever
-- enforced that. All three RPCs are `security invoker`, meaning their own
-- internal UPDATE is itself just an ordinary write subject to this exact
-- policy — so the policy being wide open for these columns means a direct
-- `PATCH /rest/v1/loans` was EXACTLY as capable as the RPCs, with none of
-- their checks: it could re-approve an already-active loan with a
-- different EMI, silently reset `outstanding` back to `amount` (erasing
-- every real repayment with zero trace — the audit trigger only fires on
-- `pending -> active/rejected`, not `active -> active`), reopen a `closed`
-- loan, or fabricate `decided_by`/`decided_at`. Worse: the `is_staff()`
-- branch had ZERO restriction at all — not even the leader branch's own
-- `loans_member_id(loans.id) <> auth.uid()` self-exclusion — so any crp/
-- clf/admin account could approve/reject/repay HER OWN loan outright,
-- reachable in practice because `AdminRepository.updateUserRole()` never
-- clears `shg_id` when promoting an existing SHG member to staff. This is
-- the same self-decision-lock gap already closed for `scheme_applications`
-- in 0049/0050, never back-ported to loans.
--
-- Fix, mirroring this codebase's own established pattern for exactly this
-- shape (`place_marketplace_order`, `guard_last_admin_deactivation`):
-- convert the three RPCs to `security definer` (their internal UPDATE now
-- bypasses RLS entirely, since the function owner is the table owner) and
-- move ALL authorization there — SHG/staff scope check AND self-exclusion,
-- explicitly, since RLS no longer does it for these RPCs' own writes — and
-- lock EVERY state-machine column at the RLS layer for any OTHER, direct
-- update path. After this migration, a direct `PATCH /rest/v1/loans` can
-- only ever be a true no-op for a leader/staff account (every column must
-- equal its currently-stored value) — matching this repo's confirmed fact
-- that no legitimate Dart call site ever writes to `loans` any other way.
--
-- One accepted side effect: `LoanRepository.approve()`/`reject()`/
-- `recordPayment()`'s PGRST202 fallback (a raw `.update().eq('status',
-- 'pending')`, kept for the gap before 0029/0073 were deployed) becomes
-- permanently unreachable dead code from this migration forward — it can
-- no longer possibly succeed once the state-machine columns are locked,
-- since the RPCs it falls back FROM are the ones now deployed alongside
-- this exact lock. Left as-is rather than removed: it only ever executes
-- if the RPC itself is missing (`PGRST202`), which cannot occur in any
-- environment that has run this migration.
--
-- Also folds in Loans audit finding #2 (round 185): `approve_loan` never
-- checked whether the borrowing member was still active before disbursing
-- pooled SHG funds to her. Reuses `profile_is_active()` (0087).

-- 42P13: RETURNS TABLE shape is widening, must drop before recreate; a
-- policy depends on it, so drop the policy first.
drop policy if exists "loans_update_leader_or_staff" on public.loans;
drop function if exists public.loans_locked_fields(uuid);

create or replace function public.loans_locked_fields(p_loan_id uuid)
returns table (
  amount numeric, purpose text, tenure_months int, created_at timestamptz,
  status text, outstanding numeric, emi numeric, disbursed_on date,
  next_due_date date, decided_by uuid, decided_at timestamptz
)
language sql
security definer
stable
set search_path = public
as $$
  select l.amount, l.purpose, l.tenure_months, l.created_at,
         l.status, l.outstanding, l.emi, l.disbursed_on,
         l.next_due_date, l.decided_by, l.decided_at
  from public.loans l
  where l.id = p_loan_id
    and (l.member_id = auth.uid() or l.shg_id = public.current_shg_id() or public.is_staff());
$$;

revoke all on function public.loans_locked_fields(uuid) from public;
grant execute on function public.loans_locked_fields(uuid) to authenticated;

create policy "loans_update_leader_or_staff" on public.loans
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  )
  with check (
    (
      (shg_id = public.current_shg_id() and public.current_role() = 'leader')
      or public.is_staff()
    )
    and member_id = public.loans_member_id(loans.id)
    and public.loans_member_id(loans.id) <> auth.uid()
    and amount = (select f.amount from public.loans_locked_fields(loans.id) f)
    and purpose = (select f.purpose from public.loans_locked_fields(loans.id) f)
    and tenure_months = (select f.tenure_months from public.loans_locked_fields(loans.id) f)
    and created_at = (select f.created_at from public.loans_locked_fields(loans.id) f)
    and status = (select f.status from public.loans_locked_fields(loans.id) f)
    and outstanding = (select f.outstanding from public.loans_locked_fields(loans.id) f)
    and emi is not distinct from (select f.emi from public.loans_locked_fields(loans.id) f)
    and disbursed_on is not distinct from (select f.disbursed_on from public.loans_locked_fields(loans.id) f)
    and next_due_date is not distinct from (select f.next_due_date from public.loans_locked_fields(loans.id) f)
    and decided_by is not distinct from (select f.decided_by from public.loans_locked_fields(loans.id) f)
    and decided_at is not distinct from (select f.decided_at from public.loans_locked_fields(loans.id) f)
  );

create or replace function public.approve_loan(p_loan_id uuid, p_emi numeric, p_next_due_date date)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_shg_id uuid;
  v_member_id uuid;
begin
  if p_emi is null or p_emi <= 0 then
    raise exception 'emi must be positive';
  end if;

  select status, shg_id, member_id into v_status, v_shg_id, v_member_id
  from public.loans where id = p_loan_id for update;

  if v_status is null then
    raise exception 'loan not found';
  end if;
  if v_status <> 'pending' then
    raise exception 'loan is no longer pending (current status: %)', v_status;
  end if;
  if v_member_id = auth.uid() then
    raise exception 'cannot approve your own loan';
  end if;
  if not ((v_shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()) then
    raise exception 'not authorized to approve this loan';
  end if;
  if not public.profile_is_active(v_member_id) then
    raise exception 'cannot approve a loan for a deactivated member';
  end if;

  update public.loans
    set status = 'active',
        disbursed_on = current_date,
        emi = p_emi,
        next_due_date = p_next_due_date,
        decided_by = auth.uid(),
        decided_at = now()
    where id = p_loan_id;
end;
$$;

revoke all on function public.approve_loan(uuid, numeric, date) from public;
grant execute on function public.approve_loan(uuid, numeric, date) to authenticated;

create or replace function public.reject_loan(p_loan_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status text;
  v_shg_id uuid;
  v_member_id uuid;
begin
  select status, shg_id, member_id into v_status, v_shg_id, v_member_id
  from public.loans where id = p_loan_id for update;

  if v_status is null then
    raise exception 'loan not found';
  end if;
  if v_status <> 'pending' then
    raise exception 'loan is no longer pending (current status: %)', v_status;
  end if;
  if v_member_id = auth.uid() then
    raise exception 'cannot reject your own loan';
  end if;
  if not ((v_shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()) then
    raise exception 'not authorized to reject this loan';
  end if;

  update public.loans set status = 'rejected', decided_by = auth.uid(), decided_at = now() where id = p_loan_id;
end;
$$;

revoke all on function public.reject_loan(uuid) from public;
grant execute on function public.reject_loan(uuid) to authenticated;

drop function if exists public.record_loan_payment(uuid, numeric);

create or replace function public.record_loan_payment(p_loan_id uuid, p_amount numeric)
returns table (new_outstanding numeric, closed boolean, new_next_due_date date)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_outstanding numeric;
  v_new_outstanding numeric;
  v_new_next_due_date date;
  v_shg_id uuid;
  v_member_id uuid;
begin
  if p_amount <= 0 then
    raise exception 'payment amount must be positive';
  end if;

  select outstanding, shg_id, member_id into v_current_outstanding, v_shg_id, v_member_id
  from public.loans
  where id = p_loan_id
  for update;

  if v_current_outstanding is null then
    raise exception 'loan not found';
  end if;
  if v_member_id = auth.uid() then
    raise exception 'cannot record a payment on your own loan';
  end if;
  if not ((v_shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()) then
    raise exception 'not authorized to record a payment on this loan';
  end if;
  if p_amount > v_current_outstanding then
    raise exception 'payment amount (%) exceeds outstanding balance (%)', p_amount, v_current_outstanding;
  end if;

  insert into public.loan_payments (loan_id, amount) values (p_loan_id, p_amount);

  v_new_next_due_date := case when v_current_outstanding - p_amount <= 0 then null else current_date + interval '30 days' end;

  update public.loans
  set outstanding = v_current_outstanding - p_amount,
      status = case when v_current_outstanding - p_amount <= 0 then 'closed' else status end,
      next_due_date = v_new_next_due_date
  where id = p_loan_id
  returning outstanding into v_new_outstanding;

  return query select v_new_outstanding, v_new_outstanding <= 0, v_new_next_due_date;
end;
$$;

revoke all on function public.record_loan_payment(uuid, numeric) from public;
grant execute on function public.record_loan_payment(uuid, numeric) to authenticated;
