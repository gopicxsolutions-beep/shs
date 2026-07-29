// Real infrastructure metrics (uptime/latency/error rate) for the Admin
// Monitoring page — closes the documented placeholder in
// admin_monitoring_page.dart (`adminMonitoringPlaceholderLabel`/
// `adminMonitoringPlaceholderDescription`) and docs/QUALITY_MANAGEMENT.md's
// own disclosure of this gap.
//
// HONEST SCOPE (same disclosure style as moderation.ts/AI_MODULES.md §6):
// this measures OUR OWN database round-trip from the Edge Function
// runtime — a real, genuine synthetic health check, logged and aggregated
// over time — NOT a full third-party APM's view of every layer of the
// stack (CDN, DNS, client-side rendering, etc). That broader claim needs a
// real APM vendor and is out of scope here, same as every other
// honestly-scoped placeholder in this codebase.
//
// Two distinct callers, both valid:
//   1. pg_cron, every 5 minutes (0114_infra_health_checks.sql) — no user
//      JWT (it's a scheduled job, not a logged-in session), authenticates
//      via the same shared `x-cron-secret` header
//      generate-report-snapshots already uses (see that function's header
//      comment for the two-step Vault/secrets setup — this reuses the
//      SAME secret, no new setup needed beyond what that migration
//      already required).
//   2. The live Admin Monitoring page itself, on load/refresh — a real
//      staff member's session JWT, so an admin sees a FRESH check the
//      instant they open the page, not just whatever the last cron tick
//      happened to record up to 5 minutes ago.
// `verify_jwt` is false at the platform level (same as
// generate-report-snapshots) since the cron caller has no JWT at all —
// this function does its own auth for both cases instead.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
};

// Same constant-time-compare rationale as generate-report-snapshots's own
// `timingSafeEqual` — a plain `!==` leaks the secret one byte at a time via
// response-timing differences.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

const STAFF_ROLES = ['crp', 'clf', 'admin'];

// Resolves whether this specific request is allowed to run a health check —
// either a trusted cron caller (shared secret) or an authenticated staff
// member (crp/clf/admin). Returns null if neither, so the caller can 401.
async function authorizeCaller(req: Request, supabaseUrl: string, anonKey: string, serviceClient: ReturnType<typeof createClient>): Promise<'cron' | 'staff' | null> {
  const cronSecret = Deno.env.get('CRON_SECRET');
  const providedSecret = req.headers.get('x-cron-secret');
  if (cronSecret && providedSecret && timingSafeEqual(providedSecret, cronSecret)) return 'cron';

  const authHeader = req.headers.get('Authorization') ?? req.headers.get('authorization');
  if (!authHeader?.startsWith('Bearer ')) return null;
  const token = authHeader.slice('Bearer '.length);

  // `verify_jwt` is false at the platform level for this function (the cron
  // caller has no JWT at all to verify), so unlike ai-advisor-proxy (which
  // trusts the platform's own gateway-level verification and only decodes
  // the `sub` claim), this function must genuinely re-verify the token
  // itself — `auth.getUser(token)` round-trips to Supabase Auth to check
  // the signature and expiry for real, not just decode-and-trust.
  const anonClient = createClient(supabaseUrl, anonKey);
  const {
    data: { user },
    error,
  } = await anonClient.auth.getUser(token);
  if (error || !user) return null;

  const { data: profile } = await serviceClient.from('profiles').select('role').eq('id', user.id).maybeSingle();
  if (!profile || !STAFF_ROLES.includes(profile.role as string)) return null;
  return 'staff';
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const serviceClient = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

    const callerType = await authorizeCaller(req, supabaseUrl, anonKey, serviceClient);
    if (!callerType) {
      return new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    // The actual synthetic check: a minimal, real round-trip to the
    // database through the same connection pool every other query in this
    // app uses — not a fake/hardcoded "always healthy" stub. `head: true`
    // (a HEAD-style count, no row data) keeps this as cheap as possible
    // since it runs every 5 minutes indefinitely.
    const start = performance.now();
    let success = true;
    let errorMessage: string | null = null;
    try {
      const { error } = await serviceClient.from('profiles').select('id', { count: 'exact', head: true });
      if (error) {
        success = false;
        errorMessage = error.message;
      }
    } catch (e) {
      success = false;
      errorMessage = e instanceof Error ? e.message : String(e);
    }
    const latencyMs = Math.round(performance.now() - start);

    const { error: insertError } = await serviceClient.from('infra_health_checks').insert({ latency_ms: latencyMs, success, error_message: errorMessage });
    if (insertError) console.error('system-health-check: failed to record this check (continuing anyway, since the check itself already ran):', insertError);

    // Opportunistic prune, same "no second scheduled job just for cleanup"
    // shape as record_system_heartbeat() — 7 days is plenty for a "last
    // 24h" rolling stat with headroom to investigate a recent incident,
    // without the table growing unbounded (288 rows/day at this interval).
    const { error: pruneError } = await serviceClient.from('infra_health_checks').delete().lt('checked_at', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString());
    if (pruneError) console.error('system-health-check: prune of old rows failed (non-fatal):', pruneError);

    // Rolling 24h stats, computed from every check in that window
    // (including the one just recorded above) — not just this single
    // invocation's own result, which alone would be a noisy, meaningless
    // "up" or "down" rather than a real uptime/error-rate figure.
    const windowStart = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { data: recentChecks, error: recentError } = await serviceClient.from('infra_health_checks').select('latency_ms, success').gte('checked_at', windowStart);
    if (recentError) throw recentError;

    const checks = recentChecks ?? [];
    const totalChecks24h = checks.length;
    const successfulChecks24h = checks.filter((c) => c.success).length;
    const uptimePercent24h = totalChecks24h > 0 ? (successfulChecks24h / totalChecks24h) * 100 : null;
    const errorRatePercent24h = totalChecks24h > 0 ? ((totalChecks24h - successfulChecks24h) / totalChecks24h) * 100 : null;
    const latencies = checks.map((c) => c.latency_ms as number).sort((a, b) => a - b);
    const avgLatencyMs24h = latencies.length > 0 ? Math.round(latencies.reduce((s, v) => s + v, 0) / latencies.length) : null;
    const p95Index = latencies.length > 0 ? Math.min(latencies.length - 1, Math.ceil(latencies.length * 0.95) - 1) : -1;
    const p95LatencyMs24h = p95Index >= 0 ? latencies[p95Index] : null;

    // Supplementary signal from the pre-existing system_heartbeats table
    // (0044) — "is our own pg_cron scheduled-job infrastructure alive at
    // all", distinct from (and a useful cross-check against) the
    // database-round-trip metrics above, which could in principle stay
    // healthy even if pg_cron itself stopped firing jobs.
    const { data: lastHeartbeat } = await serviceClient.from('system_heartbeats').select('recorded_at').order('recorded_at', { ascending: false }).limit(1).maybeSingle();
    const lastHeartbeatAgeSeconds = lastHeartbeat ? Math.round((Date.now() - new Date(lastHeartbeat.recorded_at as string).getTime()) / 1000) : null;
    // Heartbeats land every 10 minutes (0044); 15 minutes gives one full
    // missed tick of grace before flagging unhealthy, avoiding a false
    // alarm from ordinary scheduling jitter.
    const heartbeatHealthy = lastHeartbeatAgeSeconds !== null && lastHeartbeatAgeSeconds < 15 * 60;

    return new Response(
      JSON.stringify({
        ok: true,
        latencyMs,
        success,
        checkedAt: new Date().toISOString(),
        uptimePercent24h,
        errorRatePercent24h,
        avgLatencyMs24h,
        p95LatencyMs24h,
        totalChecks24h,
        lastHeartbeatAgeSeconds,
        heartbeatHealthy,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('system-health-check unhandled error:', err);
    return new Response(JSON.stringify({ ok: false, error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
