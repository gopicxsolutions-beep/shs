-- Closes a real gap found this session: generate-report-snapshots has
-- verify_jwt=false (it's cron-triggered, not called with a user JWT) but
-- had NO check of its own distinguishing the real nightly pg_cron call
-- from any other HTTP request — its URL is trivially discoverable (this
-- repo hardcodes it in 0003_scheduled_report_snapshots.sql, and the
-- functions/v1/<name> path is guessable once the project ref is known).
-- Since the function runs with the service-role key (bypasses RLS by
-- design, across every SHG in one pass), an unauthenticated caller could
-- invoke it repeatedly — a real resource-exhaustion/cost vector (DB load +
-- function-invocation billing), not the "idempotent, no side effects" free
-- pass it might look like at a glance.
--
-- Fix: the function now requires an `x-cron-secret` header matching its
-- own `CRON_SECRET` environment secret (see the updated
-- supabase/functions/generate-report-snapshots/index.ts). This migration
-- reschedules the pg_cron job to send that header, reading the actual
-- secret value from Supabase Vault at call time — NEVER hardcode the
-- secret itself in a migration file committed to the repo, the same way
-- 0003's hardcoded *URL* (not a secret, just not great practice either)
-- was already flagged as something to be mindful of.
--
-- ONE-TIME MANUAL SETUP REQUIRED before this migration is useful — run
-- both of these with a real project's credentials (this session has none):
--   1. Generate a random secret value (e.g. `openssl rand -hex 32`).
--   2. `supabase secrets set CRON_SECRET=<that value>` — sets the Edge
--      Function's copy.
--   3. In the SQL editor: `select vault.create_secret('<the SAME value>', 'cron_secret');`
--      — sets the pg_cron job's copy, read back out below via
--      `vault.decrypted_secrets`. If a `cron_secret` vault entry already
--      exists, use `vault.update_secret` instead.
-- Until step 2 is done, the function's own `Deno.env.get('CRON_SECRET')`
-- check will be absent and it'll safely fail closed (500, "Internal
-- error") rather than run unauthenticated — it does NOT silently reopen
-- the original gap.

select cron.unschedule('generate-report-snapshots-nightly');

select cron.schedule(
  'generate-report-snapshots-nightly',
  '0 2 * * *',
  $job$
  select net.http_post(
    url := 'https://pccbwfmlhpvieetetrpx.supabase.co/functions/v1/generate-report-snapshots',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'cron_secret')
    ),
    body := '{}'::jsonb
  );
  $job$
);
