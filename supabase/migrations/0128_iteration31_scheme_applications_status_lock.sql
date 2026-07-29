-- Gap-hunt iteration 31: Schemes full sweep, 1 CRITICAL finding.
--
-- `decide_scheme_application()`'s "already decided" guard (`if v_status not
-- in ('applied','under_review') then raise exception...`) is application
-- logic inside a `security invoker` function — NOT a database authorization
-- boundary. The real boundary is `scheme_applications_update_staff`'s RLS,
-- and that policy never restricted the current OR new `status` value at
-- all (unlike `scheme_id`/`member_id`/`applied_on`, which ARE locked).
-- Live-verified: a direct REST `PATCH` by any staff account on an
-- ALREADY-DECIDED application (e.g. flipping a real `rejected` decision
-- back to `approved`) succeeds, completely bypassing the RPC's
-- already-decided check since RLS itself never enforces it.
--
-- This is the exact vulnerability shape `loans` had before migration 0088
-- ("loans state machine lockdown") — `approve_loan`/`reject_loan` were also
-- unguarded at the RLS layer, so a raw PATCH was "exactly as capable as the
-- RPC, with none of its checks." Fixed the same way: lock the OLD status to
-- `('applied','under_review')` and the NEW status to `('approved',
-- 'rejected')` directly in the WITH CHECK, so a raw REST caller can only
-- ever decide a genuinely still-pending application, structurally —
-- regardless of whether it goes through `decide_scheme_application()` or
-- bypasses it entirely.

drop policy if exists "scheme_applications_update_staff" on public.scheme_applications;
drop function if exists public.scheme_applications_locked_fields(uuid);

create function public.scheme_applications_locked_fields(p_application_id uuid)
returns table (scheme_id uuid, member_id uuid, applied_on date, status text)
language sql
security definer
stable
set search_path = public
as $$
  select a.scheme_id, a.member_id, a.applied_on, a.status
  from public.scheme_applications a
  where a.id = p_application_id
    and (a.member_id = auth.uid() or public.is_staff());
$$;

revoke all on function public.scheme_applications_locked_fields(uuid) from public;
grant execute on function public.scheme_applications_locked_fields(uuid) to authenticated;

create policy "scheme_applications_update_staff" on public.scheme_applications
  for update using (
    is_staff() and member_id <> auth.uid()
  ) with check (
    is_staff()
    and member_id <> auth.uid()
    and decided_by = auth.uid()
    and decided_at = now()
    and scheme_id = (select f.scheme_id from public.scheme_applications_locked_fields(scheme_applications.id) f)
    and member_id = (select f.member_id from public.scheme_applications_locked_fields(scheme_applications.id) f)
    and applied_on = (select f.applied_on from public.scheme_applications_locked_fields(scheme_applications.id) f)
    and (select f.status from public.scheme_applications_locked_fields(scheme_applications.id) f) in ('applied', 'under_review')
    and status in ('approved', 'rejected')
  );
