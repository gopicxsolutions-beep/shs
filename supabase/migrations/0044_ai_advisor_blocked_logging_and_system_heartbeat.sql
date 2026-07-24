-- Two independent, small production-readiness gaps closed together:
--
-- 1. `ai_advisor_logs` never recorded that a request was ATTEMPTED and
--    REJECTED by content moderation (self-harm/hate-speech/jailbreak regex,
--    or the new ML classifier added in this same round) -- only successful
--    Q&A pairs were ever logged, by `AiAdvisorRepository.ask()` AFTER a
--    successful response came back (see that file, and
--    ai-advisor-proxy/index.ts's own file header: "Logging to
--    public.ai_advisor_logs stays client-side"). A caller whose request was
--    blocked left zero trace anywhere -- not even that an attempt happened --
--    which is also exactly the scenario an adversarial review flagged as the
--    real gap behind docs/AI_MODULES.md §6's disclosed "no anomaly/abuse
--    monitoring on the logs": there was nothing to monitor, because blocked
--    attempts were never persisted in the first place.
--
--    Fixed by adding `blocked`/`block_reason` columns and having
--    ai-advisor-proxy/index.ts insert a row directly (via the service-role
--    client it already holds for the rate-limit RPC call -- no new
--    SECURITY DEFINER wrapper needed, since a service-role client already
--    bypasses RLS the same way any of this schema's SECURITY DEFINER
--    functions do) whenever content moderation rejects a request, before
--    returning the 400. Deliberately scoped to CONTENT-moderation blocks
--    only (self-harm/hate-speech/jailbreak regex, history-content bypass
--    attempts, ML-classifier flags) -- NOT ordinary shape-validation 400s
--    (malformed JSON, missing fields) or 429 rate-limit rejections, which
--    are either not abuse signals worth an audit-trail row or are already
--    tracked in `ai_advisor_rate_limits`. This keeps the new column's
--    meaning narrow and genuinely useful for staff abuse review, rather than
--    diluting it with ordinary client-side mistakes.
--
-- 2. The Admin Dashboard's "System Uptime" stat has been a hardcoded
--    `'N/A'` string constant since it was added (`lib/pages/dashboard/
--    admin_dashboard.dart`'s `_systemUptime`), honestly labeled
--    "Not live-monitored" -- accurate, but a placeholder nonetheless, and
--    one this repo can genuinely close without any third-party APM
--    vendor/credential: a lightweight self-heartbeat, the same shape as
--    this schema's other pg_cron-driven, self-pruning bookkeeping tables
--    (`ai_advisor_rate_limits`, and 0043's log-purge job). It answers a
--    narrower, honest question -- "is our own scheduled-job infrastructure
--    (pg_cron) actually still running" -- not "what is the uptime/latency/
--    error-rate of every service in the stack"; that broader claim would
--    need real external APM and is explicitly out of scope here, same as
--    every other honestly-scoped placeholder in this codebase.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. ai_advisor_logs: blocked-request logging
-- ─────────────────────────────────────────────────────────────────────────

alter table public.ai_advisor_logs
  add column blocked boolean not null default false,
  add column block_reason text;

-- Keeps the two new columns' meaning coupled: a row is either a normal
-- logged Q&A (blocked = false, block_reason null) or a logged BLOCKED
-- attempt (blocked = true, block_reason set) -- never a half-populated
-- state that would be ambiguous to a staff member reading this table.
alter table public.ai_advisor_logs
  add constraint ai_advisor_logs_blocked_reason_consistency
  check (blocked = (block_reason is not null));

-- Composite index for the staff-facing abuse-review query added in this
-- round (AdminRepository.fetchAiAdvisorModerationStats(): count + distinct
-- member count of blocked rows in a recent window) -- without this, that
-- query would need a sequential scan of the whole (potentially large, given
-- 180-day retention) table on every Admin Monitoring page load.
create index if not exists ai_advisor_logs_blocked_created_at_idx
  on public.ai_advisor_logs (blocked, created_at) where blocked;

-- No RLS policy changes: the existing `ai_advisor_logs_select_self_or_staff`
-- / `ai_advisor_logs_insert_self` policies (0002_rls_policies.sql) already
-- cover these new columns automatically (row-level policies apply to the
-- whole row, not per-column), and the Edge Function inserts blocked rows
-- using its existing service-role client, which bypasses RLS entirely --
-- the same trust boundary the rate-limit RPC call already relies on. No new
-- client-facing INSERT/UPDATE/DELETE path is opened by this migration.

-- ─────────────────────────────────────────────────────────────────────────
-- 2. system_heartbeats: minimal self-monitoring for the Admin Dashboard's
--    "System Uptime" stat
-- ─────────────────────────────────────────────────────────────────────────

create table public.system_heartbeats (
  id bigint generated always as identity primary key,
  recorded_at timestamptz not null default now()
);

alter table public.system_heartbeats enable row level security;

-- Staff-only read, matching every other operational/audit table in this
-- schema (ai_advisor_logs, ai_advisor_rate_limits) -- an ordinary member has
-- no reason to see this. No INSERT/UPDATE/DELETE policy for any client role
-- at all: every write happens through the SECURITY DEFINER function below,
-- called only by pg_cron (which runs as the job owner, not through
-- PostgREST/RLS) or service_role.
create policy system_heartbeats_select_staff
  on public.system_heartbeats
  for select
  using (public.is_staff());

-- Records one heartbeat row and opportunistically prunes anything older
-- than 2 days in the same call -- this table only ever needs to answer
-- "how recently did a heartbeat last land", so nothing older than a couple
-- of days has any standalone value, and letting it self-prune here (the
-- same trick `check_and_increment_ai_advisor_rate_limit` uses, 0031) avoids
-- needing a second scheduled job just for cleanup.
create or replace function public.record_system_heartbeat() returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.system_heartbeats default values;
  delete from public.system_heartbeats where recorded_at < now() - interval '2 days';
end;
$$;

-- Same revoke-then-grant pattern as every other privileged function in this
-- schema (0017's documented "Postgres grants EXECUTE to PUBLIC by default"
-- footgun) -- not granted to `authenticated`: this function has no
-- caller-scoping at all and exists purely for the scheduled job below.
revoke all on function public.record_system_heartbeat() from public;
grant execute on function public.record_system_heartbeat() to service_role;

-- pg_cron already enabled by 0003/0043; restating is an idempotent no-op
-- guard. Every 10 minutes is frequent enough that the Admin Dashboard can
-- honestly report "healthy" within a tight window, while being far too
-- infrequent to matter as a cost/load concern for a single-row insert.
create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'system-heartbeat',
  '*/10 * * * *',
  $job$ select public.record_system_heartbeat(); $job$
);
