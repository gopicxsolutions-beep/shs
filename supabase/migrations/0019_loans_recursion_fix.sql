-- Proactive companion fix to 0018 (the marketplace_orders infinite-recursion
-- regression found live in round 36). `loans_update_leader_or_staff`
-- (0013_self_service_write_check_gaps.sql) — the fix for this session's
-- SINGLE MOST CRITICAL finding, a leader self-approving/disbursing her own
-- loan — uses the byte-for-byte identical anti-pattern that just broke
-- marketplace order status updates in production:
--
--   and member_id = (select l.member_id from public.loans l where l.id = loans.id)
--   and (select l.member_id from public.loans l where l.id = loans.id) <> auth.uid()
--
-- A subquery FROM `public.loans` inside a policy defined ON `public.loans`
-- — the exact shape that triggers `42P17: infinite recursion detected in
-- policy` (confirmed live for marketplace_orders in round 36; see that
-- round's migration/log entry for the full incident writeup). This means
-- the loan-approval flow — an SHG leader approving/rejecting/disbursing a
-- MEMBER'S (not her own) pending loan, the single most common staff-facing
-- write in this entire app — is almost certainly ALSO broken right now,
-- the exact same way: every legitimate approval attempt would hit this
-- recursion and fail with a hard error.
--
-- Could NOT be live-reproduced with the only real account available this
-- session (QA, a leader with no linked SHG — `using` blocks her before
-- ever reaching this `with check`, so there's no way to trigger the buggy
-- path with current credentials). Fixing proactively based on the
-- structural certainty of the match rather than waiting for a live
-- reproduction that isn't obtainable with the current test account — the
-- stakes (a completely broken money-moving core feature, live, right now)
-- don't justify waiting. Uses the exact same fix as 0018: move the
-- self-referencing read into a `security definer` function, whose own
-- internal query bypasses RLS (a table's owning role isn't subject to its
-- own RLS by default), breaking the recursion.

create or replace function public.loans_member_id(p_loan_id uuid)
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select l.member_id from public.loans l where l.id = p_loan_id;
$$;

revoke all on function public.loans_member_id(uuid) from public;
grant execute on function public.loans_member_id(uuid) to authenticated;

drop policy if exists "loans_update_leader_or_staff" on public.loans;

create policy "loans_update_leader_or_staff" on public.loans
  for update using (
    (shg_id = public.current_shg_id() and public.current_role() = 'leader') or public.is_staff()
  )
  with check (
    public.is_staff()
    or (
      shg_id = public.current_shg_id()
      and public.current_role() = 'leader'
      and member_id = public.loans_member_id(loans.id)
      and public.loans_member_id(loans.id) <> auth.uid()
    )
  );
