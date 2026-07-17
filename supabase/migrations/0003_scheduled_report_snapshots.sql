-- Nightly Scheduled Trigger for the generate-report-snapshots Edge
-- Function (supabase/functions/generate-report-snapshots/index.ts).
-- Runs at 02:00 UTC daily, regenerating every SHG's report_snapshots row
-- plus the federation rollup for the current period. verify_jwt is false
-- on the deployed function, so no Authorization header is required.

create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

select cron.schedule(
  'generate-report-snapshots-nightly',
  '0 2 * * *',
  $job$
  select net.http_post(
    url := 'https://pccbwfmlhpvieetetrpx.supabase.co/functions/v1/generate-report-snapshots',
    headers := '{"Content-Type": "application/json"}'::jsonb,
    body := '{}'::jsonb
  );
  $job$
);
