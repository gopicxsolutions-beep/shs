-- Corrects a real bug in 0006_production_hardening.sql: the two partial
-- unique indexes added there for report_snapshots (shg-scoped vs
-- federation, split because shg_id is nullable) cannot be used as an
-- ON CONFLICT inference target by PostgREST's `.upsert({onConflict: ...})`
-- — Postgres only infers a partial index when the INSERT's ON CONFLICT
-- clause repeats the exact same WHERE predicate, which the Supabase client
-- library has no way to express. Discovered by actually invoking the
-- redeployed generate-report-snapshots function and getting back
-- "there is no unique or exclusion constraint matching the ON CONFLICT
-- specification" — a real live-tested failure, not a hypothetical one.
--
-- Fix: replace the two partial indexes with one plain (non-partial) unique
-- index covering only the shg-scoped case (shg_id always non-null there,
-- which is the only case that ever needs a real upsert — one row per SHG
-- per period). The federation rollup (exactly one row per period, shg_id
-- always null) goes back to delete-then-insert in the edge function, since
-- a plain unique index doesn't dedupe NULLs against each other anyway, and
-- the non-atomic window for a single row is a small, acceptable tradeoff
-- compared to doing it per-SHG.

drop index if exists public.report_snapshots_shg_period_uidx;
drop index if exists public.report_snapshots_federation_period_uidx;

create unique index if not exists report_snapshots_shg_period_uidx
  on public.report_snapshots (shg_id, report_type, period);
