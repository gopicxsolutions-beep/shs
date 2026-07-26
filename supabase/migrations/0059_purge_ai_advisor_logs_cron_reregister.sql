-- `purge-ai-advisor-logs-nightly` (jobid 3, registered by 0043, scheduled
-- `0 3 * * *`) has never actually fired since its creation on 2026-07-23 —
-- live-confirmed via `cron.job_run_details`, which has zero rows for jobid
-- 3 at all, versus 4 rows for `generate-report-snapshots-nightly` (jobid 2,
-- older) and 115 for `system-heartbeat` (jobid 4, newer, also a direct SQL
-- call like this one — ruling out "direct SQL calls don't log" as the
-- explanation). `cron.job` shows it as `active: true` with the exact same
-- schedule shape as its two working siblings, and calling
-- `public.purge_old_ai_advisor_logs()` directly succeeds (0 rows deleted,
-- correctly — this project is under 8 days old, nothing is yet past the
-- 180-day retention window). The function is not the problem; something
-- about this specific job's registration in pg_cron's own scheduler state
-- is. No SQL-visible cause was found for why one job in the same `cron.job`
-- table with the same shape as its siblings would silently never fire while
-- they do.
--
-- Fix (standard pg_cron troubleshooting step, not a logic change): drop and
-- re-register the job under its same name/schedule/command. This assigns a
-- fresh jobid and re-inserts the row, which resolves the class of "job
-- exists but the scheduler isn't picking it up" issue this data is
-- consistent with. No change to the function itself or its grants — this
-- migration only touches the cron registration.

select cron.unschedule('purge-ai-advisor-logs-nightly');

select cron.schedule(
  'purge-ai-advisor-logs-nightly',
  '0 3 * * *',
  $job$ select public.purge_old_ai_advisor_logs(); $job$
);
