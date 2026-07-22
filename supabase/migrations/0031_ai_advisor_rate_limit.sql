-- Closes the "no rate limiting" gap `ai-advisor-proxy/index.ts` has
-- documented (and re-confirmed, un-fixed, across at least 3 prior audit
-- rounds — see the file's own header comment and docs/DEVELOPMENT_PROGRESS.md)
-- since the function started proxying to a real, metered LLM provider
-- (Groq). `MAX_QUERY_LENGTH` bounds cost *per call*; nothing bounded *call
-- frequency* — any single authenticated member could invoke the function in
-- a tight loop and run up real provider spend, a genuine unbounded-cost DoS
-- reachable by any signed-in user, not just an attacker with elevated
-- privilege.
--
-- Every prior round correctly declined to "fix" this with an in-process
-- counter inside the Edge Function itself: Supabase Edge Functions are
-- independent, horizontally-scaled Deno isolates with no shared memory, so
-- a same-isolate counter is trivially bypassed by concurrent requests
-- landing on different isolates, or reset by an isolate recycling between
-- calls — it would look like protection without actually being any. A real
-- fix needs a durable, atomic, race-safe store, which this migration
-- provides: a fixed-window counter table plus a single-statement
-- check-and-increment function, so concurrent requests from the same member
-- (even landing on different isolates) still serialize correctly through
-- Postgres's own row-level atomicity — the same class of guarantee 0029's
-- `decide_scheme_application`/loan-decision race guard already relies on
-- for a different concurrency problem.
--
-- Design: a 60-second fixed window (not a sliding window — a fixed window
-- is simpler, still closes the actual DoS/cost gap, and a member seeing a
-- burst allowance reset every minute is an acceptable UX trade for a chat
-- feature, not a security compromise) capped at 10 requests/window per
-- member, enforced from inside `ai-advisor-proxy` via
-- `check_and_increment_ai_advisor_rate_limit`, called with the service-role
-- client (this table has no direct client-facing RLS policies at all —
-- reachable only through the SECURITY DEFINER function below, matching the
-- "helper table, not a client-queryable resource" treatment nothing else in
-- this schema needed until now).

create table if not exists public.ai_advisor_rate_limits (
  member_id uuid not null,
  window_start timestamptz not null,
  request_count int not null default 0,
  primary key (member_id, window_start)
);

-- RLS enabled with zero policies: this table is never queried directly by
-- any client (anon or authenticated) — only ever touched via the
-- SECURITY DEFINER function below, which runs as the function owner and so
-- bypasses RLS regardless. Enabling it anyway is defense-in-depth in case a
-- future migration ever grants a client role direct table access by
-- mistake — the same belt-and-suspenders posture every other table in this
-- schema already has.
alter table public.ai_advisor_rate_limits enable row level security;

-- Atomically records one request for (member_id, current window) and
-- reports whether it's within the allowed budget. The insert/on-conflict/
-- update/returning is a single statement, so concurrent calls for the same
-- member — even from different Edge Function isolates — serialize through
-- Postgres's normal row-locking instead of racing a read-then-write.
create or replace function public.check_and_increment_ai_advisor_rate_limit(
  p_member_id uuid,
  p_max_per_window int,
  p_window_seconds int
) returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_window_start timestamptz;
  v_count int;
begin
  v_window_start := to_timestamp(floor(extract(epoch from now()) / p_window_seconds) * p_window_seconds);

  insert into public.ai_advisor_rate_limits (member_id, window_start, request_count)
  values (p_member_id, v_window_start, 1)
  on conflict (member_id, window_start)
    do update set request_count = ai_advisor_rate_limits.request_count + 1
  returning request_count into v_count;

  -- Opportunistic cleanup so this table doesn't grow unbounded — every call
  -- sweeps windows old enough that they can no longer be the "current"
  -- window for any caller, regardless of clock skew. No separate cron job
  -- needed for a table this cheap to prune inline.
  delete from public.ai_advisor_rate_limits where window_start < now() - interval '1 hour';

  return v_count <= p_max_per_window;
end;
$$;

-- Postgres grants EXECUTE on a newly created function to PUBLIC by default
-- (0017's documented footgun) — revoke that, then grant only to
-- service_role, since the only caller is `ai-advisor-proxy` using the
-- service-role key. Deliberately NOT granted to `authenticated`: this
-- function's whole purpose is a cost/abuse control the caller must not be
-- able to bypass or reset by invoking it directly as a client-callable RPC.
revoke all on function public.check_and_increment_ai_advisor_rate_limit(uuid, int, int) from public;
grant execute on function public.check_and_increment_ai_advisor_rate_limit(uuid, int, int) to service_role;
