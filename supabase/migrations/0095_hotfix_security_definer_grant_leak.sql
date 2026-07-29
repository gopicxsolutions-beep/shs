-- HOTFIX, caught by iteration 17's dogfooding audit of round 188's own new
-- functions: `support_messages_recent_count`/`support_tickets_locked_fields`
-- (migrations 0093/0094) both wrote `revoke all ... from public; grant
-- execute ... to authenticated;` — but this project's `public` schema
-- carries `ALTER DEFAULT PRIVILEGES` granting EXECUTE on newly created
-- functions directly to `anon`/`authenticated`/`service_role`, independent
-- of the `PUBLIC` pseudo-role. Revoking from `public` never touches those
-- per-role grants, so both functions were live-confirmed still callable by
-- the bare `anon` key with zero session — the exact same "revoke from
-- public isn't enough" gap migration 0055 already diagnosed and fixed once
-- for two other functions, repeated here because 0093/0094 used the older,
-- ineffective idiom instead of 0055's `revoke ... from anon, authenticated`.
--
-- Live-confirmed via `pg_proc.proacl`: both functions carried an explicit
-- `anon=X/postgres` entry alongside `authenticated=X/postgres`, granted at
-- CREATE FUNCTION time by the schema's default privileges, surviving the
-- `revoke all from public` untouched.
--
-- Impact: `support_tickets_locked_fields` is safe in practice — it already
-- internally requires `t.member_id = auth.uid() or is_staff()`, so a
-- non-owner/anon caller always got `[]` back. But `support_messages_
-- recent_count(p_sender_id, p_since)` had NO internal ownership check at
-- all — it accepted an arbitrary UUID and returned a real message count,
-- letting any caller (authenticated, or per this bug even fully
-- unauthenticated) learn how many support messages any other user sent in
-- any time window, bypassing `support_messages_select_related`'s owner/
-- staff confidentiality boundary entirely. Fixed two ways: the correct
-- revoke pattern (belt), and an internal auth.uid()-or-staff check inside
-- the function itself (suspenders) — the INSERT policy that calls it
-- always passes `auth.uid()` as `p_sender_id` already, so this adds no
-- new restriction for its own legitimate caller.
--
-- Also tightens `support_messages_bump_ticket_updated_at` (0093) to the
-- same explicit anon/authenticated revoke for consistency, even though it
-- is a trigger function and not directly callable via REST regardless
-- (`trigger functions can only be called as triggers`) — closes the gap
-- before any future refactor into a plain callable function silently
-- inherits the wide default grant.

create or replace function public.support_messages_recent_count(p_sender_id uuid, p_since timestamptz)
returns int
language sql
security definer
stable
set search_path = public
as $$
  select case
    when p_sender_id = auth.uid() or public.is_staff() then
      (select count(*)::int from public.support_messages m where m.sender_id = p_sender_id and m.created_at > p_since)
    else 0
  end;
$$;

revoke all on function public.support_messages_recent_count(uuid, timestamptz) from public, anon, authenticated;
grant execute on function public.support_messages_recent_count(uuid, timestamptz) to authenticated;

revoke all on function public.support_tickets_locked_fields(uuid) from public, anon, authenticated;
grant execute on function public.support_tickets_locked_fields(uuid) to authenticated;

revoke all on function public.support_messages_bump_ticket_updated_at() from public, anon, authenticated;
