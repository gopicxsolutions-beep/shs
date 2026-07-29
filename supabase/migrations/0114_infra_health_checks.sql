-- Real infrastructure metrics (uptime/latency/error rate) for the Admin
-- Monitoring page, closing a documented placeholder — see
-- admin_monitoring_page.dart's `adminMonitoringPlaceholderLabel`/
-- `adminMonitoringPlaceholderDescription` and docs/QUALITY_MANAGEMENT.md's
-- own disclosure of this gap. Mirrors 0044's `system_heartbeats` table
-- (same self-monitoring shape, same honest scope: this measures OUR OWN
-- database round-trip from the Edge Function runtime, not a full
-- third-party APM's view of every layer of the stack — that would need a
-- real APM vendor and is out of scope here, same as every other
-- honestly-scoped placeholder in this codebase).

create table public.infra_health_checks (
  id bigint generated always as identity primary key,
  checked_at timestamptz not null default now(),
  latency_ms integer not null,
  success boolean not null,
  error_message text
);

alter table public.infra_health_checks enable row level security;

-- Staff-only read, matching system_heartbeats/ai_advisor_logs — an ordinary
-- member has no reason to see infra diagnostics. No INSERT/UPDATE/DELETE
-- policy for any client role: every write happens through the
-- system-health-check Edge Function's service-role client, which bypasses
-- RLS the same way generate-report-snapshots/send-sms-hook already do.
create policy infra_health_checks_select_staff
  on public.infra_health_checks
  for select
  using (public.is_staff());

create index if not exists infra_health_checks_checked_at_idx on public.infra_health_checks (checked_at desc);

-- pg_cron/pg_net already enabled by 0003/0044; restating is an idempotent
-- no-op guard.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

-- Every 5 minutes: frequent enough for "uptime over the last 24h" to be a
-- meaningful, statistically real figure (288 possible checks/day) within a
-- few hours of this migration landing, without being a cost/load concern
-- for a single lightweight round-trip. Reuses the SAME 'cron_secret' Vault
-- entry 0010_report_snapshots_cron_secret.sql already set up — one shared
-- secret authenticates every cron-triggered Edge Function in this project,
-- so no new manual Vault setup step is needed beyond what 0010 already
-- required (if that migration's one-time setup was completed, this works
-- immediately; if not, see 0010's own comment for the two commands to run).
select cron.schedule(
  'system-health-check',
  '*/5 * * * *',
  $job$
  select net.http_post(
    url := 'https://pccbwfmlhpvieetetrpx.supabase.co/functions/v1/system-health-check',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $job$
);
