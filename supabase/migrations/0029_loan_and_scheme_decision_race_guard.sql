-- Dedicated concurrent-edit / stale-data audit (this session had never
-- looked at TWO DIFFERENT USERS racing each other on the same row before —
-- every prior double-submit-guard pass only covered one user double-
-- tapping). Checked every status-transition write flow reachable by more
-- than one leader/staff account on the same SHG (loan approve/reject,
-- savings-entry verification, meeting attendance, scheme-application
-- decision, support-ticket status, marketplace-order status, join-request
-- approve/reject) against both the Dart call site and the actual RLS
-- policy. Two are genuine, real gaps; the rest are already safe and are
-- documented here rather than silently skipped:
--
--   - join_requests: `approve_shg_join_request()` (0004/0023) already does
--     `select ... for update` + `if v_request.status <> 'pending' then
--     raise exception` before deciding — already correctly guarded.
--   - savings_entries: `status` only has two values ('pending','verified'),
--     the only reachable UI path (`SavingsRepository.verifyEntry()`) only
--     ever moves pending -> verified, never back — a second concurrent
--     "Verify" tap is a genuinely idempotent re-write of the same value,
--     not a real double-effect.
--   - meeting_attendance: `markAttendance()` is an upsert on a per-member
--     present/absent boolean, the same shape as a checkbox — last-write-
--     wins is the intended, correct behavior for a toggle, not a one-way
--     decision workflow.
--   - support_tickets / marketplace_orders: both UIs deliberately let staff
--     move status to ANY value at any time (a free-form dropdown / chip
--     row, not a locked one-way "pending -> decided" flow) — going
--     backward is an intentional "correct a mistake" feature, not a bug,
--     and neither status drives any further automated effect.
--
-- The two real gaps:
--
-- 1. loans: `LoanRepository.approve()`/`reject()` (lib/repositories/
--    loan_repository.dart) do a plain `update({...}).eq('id', id)` with no
--    check on the row's current status, and `loans_update_leader_or_staff`
--    (0023) permits ANY update from the SHG's leader or any staff account
--    regardless of the loan's current status — nothing server-side stops
--    a transition from a non-'pending' state. `LoanApprovalPage` lists
--    every `status == 'pending'` loan and reloads only after ITS OWN
--    action, so two staff/leader accounts genuinely can have the same
--    pending loan open at once (the exact "two staff reviewing the queue"
--    scenario this audit targets). Concretely reachable today:
--      - User A approves (status -> 'active', disbursed_on/emi/
--        next_due_date set from A's chosen EMI). User B, whose queue was
--        loaded moments earlier and still shows the loan as pending, taps
--        Reject: `reject()` blindly sets status -> 'rejected' but never
--        touches disbursed_on/emi/next_due_date, leaving the loan
--        permanently in an inconsistent "rejected but disbursed, with an
--        EMI and next-due-date on file" state.
--      - Or the reverse: User A rejects, User B's stale queue still shows
--        it pending and taps Approve — silently overturns A's rejection
--        and disburses a loan an SHG leader/staff member explicitly
--        turned down, with A never told their decision was overwritten.
--      - Or a double-approve with two different EMI figures entered by A
--        and B: whichever write lands second silently overwrites the
--        first's EMI/disbursed_on/next_due_date with no record two
--        different terms were ever considered.
--    This is a real financial data-integrity bug, not a harmless
--    idempotent re-write. Fix: two `security invoker` RPCs (same pattern
--    as `record_loan_payment`, 0011 — RLS still applies to the UPDATE
--    inside since these run as invoker, this is purely about atomically
--    checking-then-transitioning) that lock the row, verify it is still
--    'pending', and raise otherwise.
--
-- 2. scheme_applications: `SchemeRepository.decideApplication()` does the
--    same plain blind `update({'status': ...}).eq('id', applicationId)`,
--    and `scheme_applications_update_staff` (0012) is staff-only but has
--    no status check either — any staff account can flip ANY application
--    to any status regardless of its current one.
--    `SchemeApplicationsReviewPage` is explicitly staff-only and multiple
--    staff (crp/clf/admin) can legitimately share the same review queue
--    (unlike loans, this isn't even SHG-scoped — it's every application in
--    the system), each loading it independently. Two staff deciding the
--    same application around the same time means the second decision
--    silently overwrites the first (e.g. staff B's stale-queue "Approve"
--    tap flips an application staff A already rejected back to approved),
--    with no downstream financial effect but a real, silent data-
--    integrity/audit-trail bug on a government-scheme approval record —
--    exactly the class of bug this audit was asked to find. Fix: same
--    lock-then-verify-then-transition RPC pattern, restricted to the same
--    ('applied', 'under_review') scope `fetchPendingApplications()`
--    already treats as "still decidable".

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

  -- Lock the row first so a concurrent approve/reject on the same loan
  -- genuinely serializes instead of both reading the same stale 'pending'
  -- snapshot.
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
        next_due_date = p_next_due_date
    where id = p_loan_id;

  -- security invoker means this UPDATE is still subject to
  -- loans_update_leader_or_staff — a caller who passed the status check
  -- above but isn't the SHG's leader or staff would have this silently
  -- filtered to 0 rows by RLS rather than raise; FOUND catches that (and a
  -- loan deleted mid-transaction) the same way record_loan_payment (0011)
  -- does.
  if not found then
    raise exception 'not authorized to update this loan, or loan not found';
  end if;
end;
$$;

revoke all on function public.approve_loan(uuid, numeric, date) from public;
grant execute on function public.approve_loan(uuid, numeric, date) to authenticated;

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

  update public.loans set status = 'rejected' where id = p_loan_id;

  if not found then
    raise exception 'not authorized to update this loan, or loan not found';
  end if;
end;
$$;

revoke all on function public.reject_loan(uuid) from public;
grant execute on function public.reject_loan(uuid) to authenticated;

create or replace function public.decide_scheme_application(p_application_id uuid, p_approve boolean)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_status text;
begin
  select status into v_status from public.scheme_applications where id = p_application_id for update;

  if v_status is null then
    raise exception 'application not found';
  end if;
  if v_status not in ('applied', 'under_review') then
    raise exception 'application already decided (current status: %)', v_status;
  end if;

  update public.scheme_applications
    set status = case when p_approve then 'approved' else 'rejected' end
    where id = p_application_id;

  -- security invoker: still subject to scheme_applications_update_staff
  -- (0012, staff-only). FOUND guards the same silent-0-row-RLS-filter case
  -- as the two loan functions above.
  if not found then
    raise exception 'not authorized to decide this application, or application not found';
  end if;
end;
$$;

revoke all on function public.decide_scheme_application(uuid, boolean) from public;
grant execute on function public.decide_scheme_application(uuid, boolean) to authenticated;
