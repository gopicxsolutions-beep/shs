-- Gap-hunt iteration 29: dogfooding migration 0117 found the exact
-- exploit chain it was written to close is STILL completable today —
-- through two doors 0117 didn't touch, not just the one it closed.
--
-- 0117 only closed the self-PATCH avenue (a caller setting her OWN role to
-- 'leader' via the profiles_update_self_or_admin self-branch). It never
-- addressed the admin branch of that same policy, which has zero
-- constraints at all (`current_role() = 'admin'` alone satisfies the WITH
-- CHECK). Two real, currently-reachable admin-side doors still produce the
-- dangerous `role='leader' AND shg_id IS NULL` shape:
--   1. `AdminRepository.assignShg()` (lib/repositories/admin_repository.dart)
--      — a bare `update({shg_id})` with no role awareness, callable on any
--      unlinked profile regardless of its current role. If a profile is
--      ALREADY `role='leader'` (from any historical path), clicking the
--      ordinary "Assign SHG" admin remedy links her SHG while leaving
--      'leader' untouched — full leader authority, without
--      `approve_shg_join_request`/`is_staff()`'s decision path ever
--      running.
--   2. `AdminRepository.updateUserRole()` — its `if (role in
--      ('crp','clf','admin')) update.shg_id = null` branch only clears
--      shg_id for THOSE three roles. Picking 'leader' for ANY still-
--      unlinked member via the "Change Role" dialog
--      (`admin_users_page.dart`'s `_changeRole`, which offers all 5 roles
--      unconditionally) sets `role='leader'` while shg_id stays whatever
--      it already was (null, for an unlinked member) — a THIRD door into
--      the identical state, independent of `assignShg` entirely.
--
-- Live-confirmed this isn't hypothetical: a real profile
-- (a8fe99d2-2bc5-4197-bd96-b4d98a4f07b6, "uma") is CURRENTLY live in
-- production with role='leader', shg_id=null, and no shg_join_requests
-- row at all — i.e. she reached this state through one of these doors (or
-- the pre-0117 self-PATCH hole), not through approve_shg_join_request.
--
-- Root cause: this has been reactive, path-by-path patching (0117 closed
-- one path; this migration's data-fix + the two Dart-layer improvements
-- below close two more) instead of a structural fix. The actual invariant
-- this whole redesign depends on is simple and never changes: **a
-- 'leader' must always have an SHG.** Enforcing that as a table-level
-- CHECK constraint closes every CURRENT and FUTURE path at once —
-- `assignShg`, `updateUserRole`, a raw REST PATCH, any bug not yet
-- written — because Postgres itself rejects the row regardless of which
-- code path (or caller role) produced it. This is the same "structural,
-- not reactive" philosophy migration 0116 already used for `p_as_leader`
-- deriving the role solely from the approver's explicit choice.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. Data fix: downgrade the one live profile (and any other) already in
--    this now-invalid shape back to 'member' — she never received an
--    approve_shg_join_request decision granting her 'leader', so there is
--    no legitimate basis for the role. Any real leader access she needs
--    goes back through the normal join-request/approval flow, which now
--    correctly grants both shg_id and role together.
-- ─────────────────────────────────────────────────────────────────────────

update public.profiles set role = 'member' where role = 'leader' and shg_id is null;

-- ─────────────────────────────────────────────────────────────────────────
-- 2. The structural fix: a 'leader' profile must always carry a non-null
--    shg_id. This is checked for every writer — self-update, admin-update,
--    or any future RPC — not just the self-escalation path 0117 closed.
-- ─────────────────────────────────────────────────────────────────────────

alter table public.profiles add constraint profiles_leader_requires_shg check (role <> 'leader' or shg_id is not null);

-- ─────────────────────────────────────────────────────────────────────────
-- 3. [MEDIUM] `approve_shg_join_request`'s new (0117) re-validation was
--    check-then-act, not atomic: a plain `select exists(...)` read (no
--    lock on the `profiles` row — only `shg_join_requests` is `for
--    update`) followed by a separate, unconditional `UPDATE ... WHERE id =
--    v_request.member_id` with no re-check in the UPDATE's own WHERE
--    clause. Each statement in a plpgsql function body gets its own READ
--    COMMITTED snapshot, so a concurrent write (another admin action)
--    committing between the `exists()` check and the final UPDATE is
--    still silently clobbered — the exact race 0117 says it fixed, just
--    narrowed to a sub-millisecond window instead of eliminated. Folding
--    the guard into the UPDATE's own WHERE clause (checked via `GET
--    DIAGNOSTICS`) makes the check-and-write atomic: no separate read step
--    exists for a concurrent transaction to slip in after.
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.approve_shg_join_request(p_request_id uuid, p_approve boolean, p_as_leader boolean default false)
returns void
language plpgsql
security definer
set search_path = 'public'
as $function$
declare
  v_request record;
  v_updated int;
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

  if p_approve and p_as_leader and not public.is_staff() then
    raise exception 'only staff may approve a join request as leader';
  end if;

  if p_approve and not public.profile_is_active(v_request.member_id) then
    raise exception 'requester account is deactivated';
  end if;

  if p_approve then
    update public.profiles
      set shg_id = v_request.shg_id,
          role = case when p_as_leader then 'leader' else 'member' end
      where id = v_request.member_id and role = 'member' and shg_id is null;
    get diagnostics v_updated = row_count;
    if v_updated = 0 then
      raise exception 'requester account has changed since this request was filed; ask them to submit a new request';
    end if;
    update public.shg_join_requests set status = 'approved', decided_at = now(), decided_by = auth.uid() where id = p_request_id;
  else
    update public.shg_join_requests set status = 'rejected', decided_at = now(), decided_by = auth.uid() where id = p_request_id;
  end if;
end;
$function$;

revoke all on function public.approve_shg_join_request(uuid, boolean, boolean) from public, anon;
grant execute on function public.approve_shg_join_request(uuid, boolean, boolean) to authenticated;
