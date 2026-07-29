-- Gap-hunt iteration 22 (round 195): 4 parallel audits (dogfood round 194,
-- Notifications/Announcements/Support, AI Advisors, Meetings + Livelihood)
-- — this migration closes every RLS/backend gap among them.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. [HIGH] `course_progress_write_self_or_staff`'s round-194 fix only
--    added self-exclusion (`member_id <> auth.uid()`) — but the staff
--    branch still let staff set `certified`/`completed_on` to ANY value
--    for ANY OTHER member's row, with no lock. Live-verified this round: a
--    CRP could set `certified=true` for a different member on a course
--    with zero quiz questions attached — no quiz ever taken, bypassing
--    `submit_quiz_attempt` (the app's only intended certification path,
--    FR-TRN-3) for someone else's record. No UI call site anywhere in
--    `lib/` uses this staff-writes-another's-row path (confirmed by grep)
--    — the same "unused, should be locked rather than patched" situation
--    round 194 itself used to justify dropping `marketplace_orders_
--    insert_staff` entirely. `certified`/`completed_on` are now locked to
--    their existing stored values for the staff branch too — staff
--    genuinely has no legitimate reason to set these for anyone, they're
--    earned exclusively via the quiz.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "course_progress_write_self_or_staff" on public.course_progress;

create policy "course_progress_write_self_or_staff" on public.course_progress
  for all using (member_id = auth.uid() or public.is_staff())
  with check (
    (
      public.is_staff()
      and profile_is_active(member_id)
      and member_id <> auth.uid()
      and certified is not distinct from coalesce((select f.certified from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f), false)
      and completed_on is not distinct from (select f.completed_on from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f)
    )
    or (
      member_id = auth.uid()
      and profile_is_active(member_id)
      and certified = coalesce((select f.certified from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f), false)
      and completed_on is not distinct from (select f.completed_on from public.course_progress_locked_fields(course_progress.course_id, course_progress.member_id) f)
    )
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. [MEDIUM] `financial_ledger_is_latest()` (round 194) used `created_at >`
--    as its tiebreak, which lets TWO rows sharing an identical `created_at`
--    both classify as "latest" — both then independently deletable, not
--    just the single most-recent row the fix claims to restrict to.
--    Switched to a deterministic `row_number()` ranking (created_at desc,
--    id desc as the final tiebreak) so exactly one row per
--    `(shg_id, entry_type)` group is ever "latest".
-- ─────────────────────────────────────────────────────────────────────────

create or replace function public.financial_ledger_is_latest(p_id uuid)
returns boolean
language sql
stable security definer
set search_path = public
as $$
  select coalesce((
    select rn = 1
    from (
      select l.id, row_number() over (
        partition by l.shg_id, l.entry_type
        order by l.created_at desc, l.id desc
      ) as rn
      from public.financial_ledger l
      join public.financial_ledger this_row on this_row.shg_id = l.shg_id and this_row.entry_type = l.entry_type
      where this_row.id = p_id
    ) ranked
    where ranked.id = p_id
  ), false);
$$;

revoke all on function public.financial_ledger_is_latest(uuid) from public, anon;
grant execute on function public.financial_ledger_is_latest(uuid) to authenticated;

-- ─────────────────────────────────────────────────────────────────────────
-- 3. [MEDIUM] `announcements_delete_staff` was bare `is_staff()` — the same
--    "is_staff() branch left wide open" self-dealing pattern this codebase
--    has now found and fixed on 6+ other tables, missed here because the
--    round-193 sweep never reached `announcements`. Live-verified: a
--    staff account could delete an announcement she authored herself
--    (e.g. while still a leader, before promotion) with no independent
--    check.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "announcements_delete_staff" on public.announcements;

create policy "announcements_delete_staff" on public.announcements
  for delete using (public.is_staff() and created_by <> auth.uid());

-- ─────────────────────────────────────────────────────────────────────────
-- 4. [HIGH] `ai_advisor_logs_insert_self`'s round-103 fix closed the
--    `blocked=true`/`block_reason` forgery vector but never bounded
--    `query`/`response` length — a member could insert an arbitrary,
--    unbounded-length, entirely fabricated `response` that never touched
--    Groq/moderation at all, with `blocked=false` making it invisible to
--    the admin moderation-stats dashboard. Live-verified this round: an
--    ~18,500-char fabricated response inserted successfully. Capping both
--    fields at `MAX_HISTORY_FIELD_CHARS` (2000, the same limit already
--    enforced server-side for genuine history entries in
--    `supabase/functions/ai-advisor-proxy/history.ts`) closes the
--    unbounded-storage vector and keeps a directly-inserted row bounded to
--    what a genuine exchange could ever look like. This does not (and
--    structurally cannot, via RLS alone) prove a `response` was actually
--    generated by Groq — that requires moving the insert server-side,
--    flagged as a follow-up, not attempted in this migration.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "ai_advisor_logs_insert_self" on public.ai_advisor_logs;

create policy "ai_advisor_logs_insert_self" on public.ai_advisor_logs
  for insert with check (
    member_id = auth.uid()
    and blocked = false
    and block_reason is null
    and char_length(query) <= 2000
    and (response is null or char_length(response) <= 2000)
  );
