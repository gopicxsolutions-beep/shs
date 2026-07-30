-- Gap-hunt iteration 41 dogfooding: migration 0146's cancel-guard sweep
-- covered every INSERT/UPDATE/DELETE policy on meeting_action_items and
-- the INSERT policy on meeting_minutes, but missed `meeting_minutes_
-- delete_staff` (bare `is_staff()`, from migration 0026, no shg/status
-- check at all) — the one remaining way to reshape a cancelled meeting's
-- durable decision record. Live-verified: inserted a real minutes row on
-- an active test meeting, cancelled the meeting, then deleted the minutes
-- row as staff — succeeded with no error, contradicting 0146's own stated
-- rationale for this exact table pair.
drop policy if exists "meeting_minutes_delete_staff" on public.meeting_minutes;
create policy "meeting_minutes_delete_staff" on public.meeting_minutes
  for delete using (
    public.is_staff()
    and exists (select 1 from public.meetings m where m.id = meeting_minutes.meeting_id and m.status <> 'cancelled')
  );
