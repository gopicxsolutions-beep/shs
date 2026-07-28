-- record_loan_payment never advances next_due_date — it's set once at
-- approval (loan_approval_page.dart, hardcoded today + 30 days) and then
-- frozen forever, even as correct payments are recorded. Every "next EMI
-- due" display (member/leader dashboards, loan detail/tracking pages)
-- shows that same stale date drifting further into the past on every
-- loan, for its entire active life. Distinct from the already-disclosed
-- "no automated overdue-status trigger" placeholder (docs/SRS.md) — that's
-- about the missing status flip; this is the underlying date the whole
-- concept depends on never moving at all.
--
-- Fix: advance next_due_date by the same 30-day cadence used at approval
-- time on every successful payment, or clear it to null once the loan
-- closes (outstanding reaches 0 — nothing is "next due" on a paid-off
-- loan). Returned from the function so the Dart layer can reflect it
-- immediately without a second round-trip.

-- Postgres refuses `create or replace` when the OUT-parameter row shape
-- changes (42P13) — must drop the old 2-out-column signature first.
drop function if exists public.record_loan_payment(uuid, numeric);

create or replace function public.record_loan_payment(p_loan_id uuid, p_amount numeric)
returns table (new_outstanding numeric, closed boolean, new_next_due_date date)
language plpgsql
as $$
declare
  v_current_outstanding numeric;
  v_new_outstanding numeric;
  v_new_next_due_date date;
begin
  if p_amount <= 0 then
    raise exception 'payment amount must be positive';
  end if;

  select outstanding into v_current_outstanding
  from public.loans
  where id = p_loan_id
  for update;

  if v_current_outstanding is null then
    raise exception 'loan not found';
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

  if not found then
    raise exception 'not authorized to update this loan, or loan not found';
  end if;

  return query select v_new_outstanding, v_new_outstanding <= 0, v_new_next_due_date;
end;
$$;

revoke all on function public.record_loan_payment(uuid, numeric) from public;
grant execute on function public.record_loan_payment(uuid, numeric) to authenticated;
