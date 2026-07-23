-- Closes the retention gap docs/AI_MODULES.md §4/§7 has disclosed since the
-- table was created: `ai_advisor_logs` has no UPDATE/DELETE policy for
-- clients (correctly -- see 0002_rls_policies.sql's
-- `ai_advisor_logs_select_self_or_staff` / `_insert_self`, re-confirmed
-- intentional by 0026/0036/0038/0039's own gap-audits, none of which added
-- one) but ALSO no retention/TTL/purge mechanism of any kind -- unlike its
-- sibling `ai_advisor_rate_limits`, which self-prunes rows older than an
-- hour on every `check_and_increment_ai_advisor_rate_limit` call (0031),
-- `ai_advisor_logs` has grown unbounded since inception.
--
-- Why this can't just copy 0031's "opportunistic delete inline in the same
-- function" trick verbatim: that trick works for
-- `ai_advisor_rate_limits` because every write to it already goes through
-- one SECURITY DEFINER function (`check_and_increment_ai_advisor_rate_limit`,
-- called once per proxy invocation from `ai-advisor-proxy/index.ts` with the
-- service-role key) -- there's a single, already-privileged choke point to
-- piggyback a `delete ... where` on. `ai_advisor_logs` has no such choke
-- point: every row is written by a plain client-side
-- `insert into ai_advisor_logs` under `ai_advisor_logs_insert_self`
-- (`lib/repositories/ai_advisor_repository.dart`'s `logQuery()`), run with
-- the member's own JWT, not a privileged function call. Piggybacking a
-- delete on that path would mean either (a) granting authenticated clients
-- a DELETE policy just so a helper function could ride along with their
-- privileges -- which reopens exactly the client-facing delete path this
-- table has deliberately never had -- or (b) wrapping every insert in a new
-- SECURITY DEFINER RPC, a much bigger surface change than a retention fix
-- warrants and out of scope for this migration. A scheduled, privileged,
-- server-side purge is the correct shape for this table, not opportunistic
-- inline cleanup.
--
-- Retention window: 180 days. This table is explicitly staff-readable
-- (`ai_advisor_logs_select_self_or_staff`) -- it's an audit trail of member
-- Q&A with the financial/scheme/market advisors, not a transient cache like
-- `ai_advisor_rate_limits` (1-hour window, pure abuse-control bookkeeping
-- with zero standalone value once its window closes). Logged advice has
-- real value for a while after the fact: a member disputing what an advisor
-- told her, a staff review of advisor quality/abuse, or an incident
-- investigation all plausibly need logs from weeks or a few months back, not
-- just today. 180 days (~6 months) is chosen as a deliberately simple,
-- round default that covers any realistic such window for this app's actual
-- usage pattern while still bounding the table's long-run growth -- there is
-- no specific regulatory/compliance retention period on record for this
-- data (this app does not currently claim one), so this is a sensible
-- operational default, not a compliance-driven figure. Revisit here if a
-- concrete legal/compliance retention requirement is ever set for this
-- table.
--
-- Enforcement stays entirely server-side and privileged, per this table's
-- existing posture: no new client-facing DELETE policy is added, and
-- `ai_advisor_logs_select_self_or_staff` / `ai_advisor_logs_insert_self`
-- (0002_rls_policies.sql) are untouched. The purge function below is
-- SECURITY DEFINER (bypasses RLS the same way
-- `check_and_increment_ai_advisor_rate_limit` does) and its EXECUTE grant is
-- revoked from `public`/never granted to `authenticated` or `anon` -- it is
-- reachable only by a role that can already do anything to this table
-- (`service_role`, or `postgres`/the job owner via pg_cron below), never by
-- an ordinary signed-in member calling it as a PostgREST RPC.
create or replace function public.purge_old_ai_advisor_logs() returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted bigint;
begin
  delete from public.ai_advisor_logs where created_at < now() - interval '180 days';
  get diagnostics v_deleted = row_count;
  return v_deleted;
end;
$$;

-- Postgres grants EXECUTE on a newly created function to PUBLIC by default
-- (0017's documented footgun) -- revoke that immediately, then grant only to
-- service_role. Deliberately NOT granted to `authenticated`: unlike most
-- SECURITY DEFINER helpers in this schema (which exist so an ordinary user
-- action can safely read/write a bit more than their own RLS otherwise
-- allows), this function's only purpose is bulk privileged deletion with no
-- caller-scoping at all -- it must not be invocable as a client RPC by any
-- signed-in member.
revoke all on function public.purge_old_ai_advisor_logs() from public;
grant execute on function public.purge_old_ai_advisor_logs() to service_role;

-- pg_cron already enabled by 0003_scheduled_report_snapshots.sql;
-- `create extension if not exists` is idempotent, so restating it here is a
-- harmless guard in case this migration is ever applied to a project where
-- 0003 was skipped. pg_net is deliberately NOT (re-)enabled here: unlike
-- `generate-report-snapshots` (which must reach an Edge Function over HTTP,
-- because its work happens outside Postgres), this purge is pure SQL --
-- pg_cron can invoke a SECURITY DEFINER function directly with no HTTP hop,
-- no Edge Function to deploy, and no cron-secret header to manage. That
-- makes this the simpler of the two established scheduled-job patterns in
-- this repo, and a sufficient fit for a single bounded DELETE.
create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule(
  'purge-ai-advisor-logs-nightly',
  '0 3 * * *',
  $job$ select public.purge_old_ai_advisor_logs(); $job$
);
