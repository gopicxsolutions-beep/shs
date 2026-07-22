// Generates public.report_snapshots rows (report_type 'shg' per SHG, plus
// one 'federation' rollup) from live tables — the server-side counterpart
// to the client-side computation in lib/repositories/report_repository.dart
// and lib/repositories/analytics_repository.dart. Runs with the
// service-role key (auto-injected by Supabase as SUPABASE_SERVICE_ROLE_KEY
// for every deployed function), so it bypasses RLS by design — this is the
// one place allowed to write report_snapshots on behalf of every SHG in a
// single pass, matching report_snapshots_write_staff's intent that only a
// trusted server-side process (not arbitrary clients) populates this table.
//
// Runs nightly via the pg_cron job in
// 0010_report_snapshots_cron_secret.sql (0 2 * * * UTC); can also be
// invoked manually via POST any time (with the same `x-cron-secret`
// header — see below). See docs/DEVELOPMENT_PROGRESS.md's Edge Functions
// entry.
//
// Auth: verify_jwt is false on this function (it's cron-triggered, not
// called with a user JWT), so this checks its own shared secret instead —
// without this, anyone who has this function's URL (trivially discoverable
// from this repo, or by guessing the standard functions/v1/<name> path)
// could invoke it at will using the service-role key to bypass RLS across
// every SHG, with zero rate limiting. Set the same value in both places
// before deploying:
//   supabase secrets set CRON_SECRET=<a random value>
//   select vault.create_secret('<the same random value>', 'cron_secret');
// (the migration reads the vault secret into the pg_cron job's request
// header — see 0010_report_snapshots_cron_secret.sql for the exact SQL).

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-cron-secret',
};

function currentPeriod(): string {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
}

// A plain `!==` compare on the secret leaks its value one character at a
// time via response-timing differences (JS string inequality short-circuits
// on the first mismatched byte) — the same class of side channel
// payment-webhook-handler's HMAC check already guards against with a
// constant-time compare. It matters more here, not less: this endpoint's
// own header comment above already documents "zero rate limiting" on this
// function, so nothing would slow down or cap the thousands of requests a
// real timing attack needs, and a successful guess gets the attacker a
// service-role connection that bypasses RLS across every SHG.
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const cronSecret = Deno.env.get('CRON_SECRET');
    if (!cronSecret) {
      // Our own deployment is misconfigured — not the caller's fault, but
      // still refuse to run rather than silently operating unauthenticated.
      console.error('generate-report-snapshots: CRON_SECRET is not configured — run `supabase secrets set CRON_SECRET=...` and set the matching vault secret before deploying.');
      return new Response(JSON.stringify({ ok: false, error: 'Internal error' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }
    const providedSecret = req.headers.get('x-cron-secret');
    if (!providedSecret || !timingSafeEqual(providedSecret, cronSecret)) {
      return new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
    }

    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const period = currentPeriod();

    const { data: shgs, error: shgsError } = await supabase.from('shgs').select('id, name');
    if (shgsError) throw shgsError;

    let shgSnapshots = 0;
    let totalSavingsAll = 0;
    let totalOutstandingAll = 0;
    let totalMembersAll = 0;
    // Tracked per-SHG (not thrown out of the loop) so a single bad SHG —
    // a null/malformed row, a transient network hiccup on one of the four
    // parallel selects, a constraint violation on that SHG's upsert —
    // can't silently take down every OTHER SHG's snapshot for the night.
    // Before this fix, `if (upsertError) throw upsertError` (still present
    // further down, now inside the per-SHG try/catch instead of the bare
    // loop body) propagated straight to the function's outer catch, which
    // aborts the whole run: every SHG later in `shgs`'s iteration order
    // than the failing one would be left with a stale (or missing)
    // snapshot for the day, with nothing in the response distinguishing
    // "ran fine" from "died halfway through". Equally real: the four
    // `Promise.all` selects below (members/savings/loans/meetings) were
    // destructured without checking `.error`, so a failed select silently
    // produced `undefined` data, which `?? []` then turned into a *wrong*
    // zero rather than a caught failure — the snapshot would report e.g.
    // total_savings: 0 for that SHG and look like a legitimately empty
    // SHG instead of a fetch that failed.
    const failedShgIds: string[] = [];

    // `status = 'completed'` never actually matches in live mode — nothing
    // in the app ever calls `MeetingRepository.setStatus()` (see
    // `Meeting.hasPassed`'s doc comment in lib/models/meeting.dart), so a
    // real meeting's status stays 'upcoming' forever. Use the meeting's own
    // date instead, the same fix already applied client-side in
    // `MeetingRepository.fetchAttendanceHistory()` and
    // `ReportRepository`'s attendance queries — without this, every
    // snapshot's `avg_attendance_pct` was permanently written as 0.
    const todayStr = new Date().toISOString().split('T')[0];

    for (const shg of shgs ?? []) {
      try {
        const [
          { data: members, error: membersError },
          { data: savings, error: savingsError },
          { data: loans, error: loansError },
          { data: meetings, error: meetingsError },
        ] = await Promise.all([
          supabase.from('profiles').select('id').eq('shg_id', shg.id),
          supabase.from('savings_entries').select('amount').eq('shg_id', shg.id).eq('status', 'verified'),
          supabase.from('loans').select('outstanding, status').eq('shg_id', shg.id),
          supabase.from('meetings').select('id').eq('shg_id', shg.id).neq('status', 'cancelled').lt('meeting_date', todayStr),
        ]);
        // Surface a failed select as a thrown error (caught below, isolated
        // to this SHG) instead of letting `?? []` silently turn it into a
        // false "this SHG legitimately has zero savings/loans/members" zero.
        if (membersError) throw membersError;
        if (savingsError) throw savingsError;
        if (loansError) throw loansError;
        if (meetingsError) throw meetingsError;

        const memberCount = members?.length ?? 0;
        const totalSavings = (savings ?? []).reduce((sum, r) => sum + Number(r.amount), 0);
        let totalOutstanding = 0;
        let activeLoanCount = 0;
        for (const loan of loans ?? []) {
          if (loan.status === 'active' || loan.status === 'overdue') {
            totalOutstanding += Number(loan.outstanding);
            activeLoanCount++;
          }
        }
        const meetingIds = (meetings ?? []).map((m) => m.id);
        let avgAttendancePct = 0;
        if (meetingIds.length > 0 && memberCount > 0) {
          const { data: attendance, error: attendanceError } = await supabase.from('meeting_attendance').select('present').in('meeting_id', meetingIds);
          if (attendanceError) throw attendanceError;
          const presentCount = (attendance ?? []).filter((a) => a.present === true).length;
          avgAttendancePct = (presentCount / (meetingIds.length * memberCount)) * 100;
        }

        // Upserts against report_snapshots_shg_period_uidx (a partial unique
        // index on (shg_id, report_type, period) where shg_id is not null,
        // added in 0006_production_hardening.sql) — atomic re-generation for
        // the same period, replacing the previous non-atomic delete-then-insert.
        const { error: upsertError } = await supabase.from('report_snapshots').upsert(
          {
            shg_id: shg.id,
            report_type: 'shg',
            period,
            data: { shg_name: shg.name, member_count: memberCount, total_savings: totalSavings, total_outstanding: totalOutstanding, active_loan_count: activeLoanCount, avg_attendance_pct: avgAttendancePct },
            generated_at: new Date().toISOString(),
          },
          { onConflict: 'shg_id,report_type,period' },
        );
        if (upsertError) throw upsertError;

        shgSnapshots++;
        totalSavingsAll += totalSavings;
        totalOutstandingAll += totalOutstanding;
        totalMembersAll += memberCount;
      } catch (shgErr) {
        // Isolate the failure to this one SHG — log server-side and move on
        // so the other SHGs in tonight's run (and the federation rollup,
        // computed from whichever SHGs succeeded) aren't collateral damage.
        console.error(`generate-report-snapshots: failed to generate snapshot for SHG ${shg.id} (${shg.name ?? 'unknown'}):`, shgErr);
        failedShgIds.push(shg.id);
      }
    }

    // The federation rollup's shg_id is always null, and Postgres unique
    // indexes never dedupe NULLs against each other, so there's no real
    // constraint to upsert against here (see 0007_report_snapshots_upsert_fix.sql) —
    // delete-then-insert for this single row instead. The per-SHG loop
    // above uses a real upsert since shg_id is always non-null there.
    const { error: federationDeleteError } = await supabase.from('report_snapshots').delete().is('shg_id', null).eq('report_type', 'federation').eq('period', period);
    if (federationDeleteError) throw federationDeleteError;
    const { error: federationError } = await supabase.from('report_snapshots').insert({
      shg_id: null,
      report_type: 'federation',
      period,
      data: { shg_count: shgs?.length ?? 0, member_count: totalMembersAll, total_savings: totalSavingsAll, total_outstanding: totalOutstandingAll },
    });
    if (federationError) throw federationError;

    // `ok: true` here means "the run completed", not "every SHG succeeded" —
    // failed_shg_count/failed_shg_ids surface partial failures explicitly
    // rather than the response looking identical to a fully clean run.
    return new Response(
      JSON.stringify({
        ok: true,
        period,
        shg_snapshots: shgSnapshots,
        shg_total: shgs?.length ?? 0,
        failed_shg_count: failedShgIds.length,
        failed_shg_ids: failedShgIds,
        federation_snapshot: true,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    // Log the real detail server-side; an unauthenticated-until-now caller
    // (see the secret check above) should never have received raw
    // Postgres/Supabase error text (table/column/constraint names) in the
    // response body, which it previously did.
    console.error('generate-report-snapshots unhandled error:', err);
    return new Response(JSON.stringify({ ok: false, error: 'Internal error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
