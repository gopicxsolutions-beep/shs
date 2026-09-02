-- Gap-hunt iteration 42: three fresh audits found real gaps.
--
-- 1. [MEDIUM, dogfooding] `meeting_minutes_delete_staff` (0148) added the
--    cancel-guard but never restricted deletion to the current-latest row
--    the way its sibling `financial_ledger_delete_staff` does — `meeting_
--    minutes` is genuinely append-only-by-design (`saveMinutes()` always
--    INSERTs, never UPDATEs, so a meeting can accumulate a real
--    versioned history), so staff could silently erase an OLDER decision
--    snapshot while leaving the newest one intact, corrupting the
--    historical record exactly the way 0026/0079 reasoned this table
--    must never allow. Live-verified: a crp account deleted a
--    non-latest minutes row on a still-active meeting while the newest
--    row survived untouched. Fixed with a `meeting_minutes_is_latest()`
--    helper mirroring `financial_ledger_is_latest()`'s established
--    pattern (security definer, avoids the 42P17 self-referencing-
--    subquery recursion class).
create or replace function public.meeting_minutes_is_latest(p_id uuid)
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select not exists (
    select 1 from public.meeting_minutes newer
    join public.meeting_minutes this_row on this_row.id = p_id
    where newer.meeting_id = this_row.meeting_id
      and (newer.created_at, newer.id) > (this_row.created_at, this_row.id)
  );
$$;

revoke all on function public.meeting_minutes_is_latest(uuid) from public, anon;
grant execute on function public.meeting_minutes_is_latest(uuid) to authenticated;

drop policy if exists "meeting_minutes_delete_staff" on public.meeting_minutes;
create policy "meeting_minutes_delete_staff" on public.meeting_minutes
  for delete using (
    public.is_staff()
    and public.meeting_minutes_is_latest(id)
    and exists (select 1 from public.meetings m where m.id = meeting_minutes.meeting_id and m.status <> 'cancelled')
  );

-- 2. [MEDIUM] `schemes` had no server-side content validation at all — a
--    live-verified direct write (`name=''`, `benefit` = 50,000 chars)
--    succeeded, since `schemes_write_admin` only checks the caller's
--    role, and no CHECK constraint existed on any text column. The admin
--    form's blank-name guard and maxLength caps are client-side only.
alter table public.schemes
  add constraint schemes_name_not_blank check (char_length(btrim(name)) > 0),
  add constraint schemes_name_length check (char_length(name) <= 100),
  add constraint schemes_benefit_length check (benefit is null or char_length(benefit) <= 300),
  add constraint schemes_agency_length check (agency is null or char_length(agency) <= 150);

-- 3. [MEDIUM] `shgs.grade` had no server-side validation — a live-verified
--    direct write stored an arbitrary garbage string, which silently
--    breaks `EligibilityCriteria.minShgGrade`'s scheme-eligibility
--    comparison (a malformed grade never matches any real grade, so it
--    always fails eligibility with no error surfaced to anyone).
alter table public.shgs
  add constraint shgs_grade_valid check (grade is null or grade in ('A+', 'A', 'B+', 'B', 'C'));
