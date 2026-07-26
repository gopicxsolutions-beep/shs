-- `approve_shg_join_request()` (0004, redefined 0023) has never actually
-- had a row lock, despite 0029's own comment (lines 12-14) explicitly
-- claiming "join_requests: approve_shg_join_request() (0004/0023) already
-- does `select ... for update` + `if v_request.status <> 'pending' then
-- raise exception` before deciding — already correctly guarded" and
-- excluding it from that round's race-guard fix on that basis. Re-read both
-- 0004's and 0023's actual function bodies directly: neither ever contained
-- a `for update` clause. That assertion was factually wrong from the moment
-- it was written, not a later regression — this gap has been open the
-- entire time 0029 has been relied on as evidence it was already closed.
--
-- Concretely reachable: `shg_join_requests_page.dart` (leader queue) and
-- any `is_staff()` account can independently load the same pending
-- request and decide it. Two decisions racing on the same request — a
-- leader approving while a CRP/CLF/admin simultaneously rejects (or a
-- leader double-tapping fast enough to fire two calls before the first
-- commits) — both read the same stale 'pending' snapshot, both pass the
-- `status <> 'pending'` check, and both write. Whichever commits last wins
-- the final `status`; if the approve committed first, the member's
-- `profiles.shg_id`/`role` have already been changed even if the request
-- row ends up 'rejected' moments later — leaving the join request's own
-- status permanently inconsistent with the member's actual membership
-- state, with no error surfaced to either decider.
--
-- Fix: exactly the pattern 0029 established for loans/scheme_applications
-- — lock the row first so a concurrent decision genuinely serializes
-- instead of both reading the same pre-decision snapshot. This function is
-- `security definer` with its own inline authorization check (unlike the
-- `security invoker` loan/scheme RPCs), so there is no RLS-silent-filter
-- case to guard with `FOUND` here — the existing explicit `not (...) then
-- raise` already covers authorization. Only the missing lock is added;
-- the leader-self-demotion logic, decided_by attribution, and
-- authorization check are otherwise byte-for-byte unchanged from 0023.

create or replace function public.approve_shg_join_request(p_request_id uuid, p_approve boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
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
$$;
