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
// Not yet wired to a schedule — invoke manually via POST, or attach a
// Supabase Scheduled Trigger / pg_cron job once a real cadence is decided
// (e.g. nightly). See docs/DEVELOPMENT_PROGRESS.md's Edge Functions entry.

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function currentPeriod(): string {
  const now = new Date();
  return `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
    const period = currentPeriod();

    const { data: shgs, error: shgsError } = await supabase.from('shgs').select('id, name');
    if (shgsError) throw shgsError;

    let shgSnapshots = 0;
    let totalSavingsAll = 0;
    let totalOutstandingAll = 0;
    let totalMembersAll = 0;

    for (const shg of shgs ?? []) {
      const [{ data: members }, { data: savings }, { data: loans }, { data: meetings }] = await Promise.all([
        supabase.from('profiles').select('id').eq('shg_id', shg.id),
        supabase.from('savings_entries').select('amount').eq('shg_id', shg.id),
        supabase.from('loans').select('outstanding, status').eq('shg_id', shg.id),
        supabase.from('meetings').select('id').eq('shg_id', shg.id).eq('status', 'completed'),
      ]);

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
        const { data: attendance } = await supabase.from('meeting_attendance').select('present').in('meeting_id', meetingIds);
        const presentCount = (attendance ?? []).filter((a) => a.present === true).length;
        avgAttendancePct = (presentCount / (meetingIds.length * memberCount)) * 100;
      }

      // report_snapshots has no unique constraint on (shg_id, report_type,
      // period) to upsert against, so re-generation for the same period is
      // idempotent via delete-then-insert instead.
      const { error: deleteError } = await supabase.from('report_snapshots').delete().eq('shg_id', shg.id).eq('report_type', 'shg').eq('period', period);
      if (deleteError) throw deleteError;
      const { error: insertError } = await supabase.from('report_snapshots').insert({
        shg_id: shg.id,
        report_type: 'shg',
        period,
        data: { shg_name: shg.name, member_count: memberCount, total_savings: totalSavings, total_outstanding: totalOutstanding, active_loan_count: activeLoanCount, avg_attendance_pct: avgAttendancePct },
      });
      if (insertError) throw insertError;

      shgSnapshots++;
      totalSavingsAll += totalSavings;
      totalOutstandingAll += totalOutstanding;
      totalMembersAll += memberCount;
    }

    const { error: federationDeleteError } = await supabase.from('report_snapshots').delete().is('shg_id', null).eq('report_type', 'federation').eq('period', period);
    if (federationDeleteError) throw federationDeleteError;
    const { error: federationError } = await supabase.from('report_snapshots').insert({
      shg_id: null,
      report_type: 'federation',
      period,
      data: { shg_count: shgs?.length ?? 0, member_count: totalMembersAll, total_savings: totalSavingsAll, total_outstanding: totalOutstandingAll },
    });
    if (federationError) throw federationError;

    return new Response(JSON.stringify({ ok: true, period, shg_snapshots: shgSnapshots, federation_snapshot: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ ok: false, error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
