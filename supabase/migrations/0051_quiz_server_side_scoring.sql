-- ─────────────────────────────────────────────────────────────────────────
-- Training quiz: server-side scoring, answer masking, and certification
-- lockdown
--
-- Live-verified two compounding gaps before this migration:
--
-- 1. `quiz_questions_select_all` (`auth.role() = 'authenticated'`) lets any
--    authenticated user read every column via a direct REST call, including
--    `correct_index` — the quiz's own answer key ships to the client before
--    the member ever answers a single question. `course_quiz_page.dart`'s
--    `_submit()` then grades entirely client-side by comparing the
--    learner's picks against that same `correctIndex` it already received.
--
-- 2. `course_progress_write_self_or_staff`'s `with check` was just
--    `member_id = auth.uid() or is_staff()` — no restriction on WHAT a
--    member can write to her own row. `TrainingRepository.markCertified()`
--    upserts `{progress: 100, certified: true, completed_on: today}`
--    directly from the client with **zero score or answer data sent to the
--    server at all** — a member (or any REST-savvy user) could call this
--    directly, or simply skip the quiz UI entirely and issue the same
--    upsert by hand, and the server would accept "I passed" on faith. This
--    feeds `AdminRepository.trainingCompletionPctFrom`, a federation-level
--    SHG-health metric — a member self-certifying without ever answering a
--    question corrupts that aggregate, not just her own record.
--
-- Fixed with the same three-part pattern already established elsewhere in
-- this schema: a masking view (mirrors `shg_own_masked`) so the answer key
-- is never sent to the client at all; a `security definer` RPC (mirrors
-- `add_financial_ledger_entry`/`decide_scheme_application`) that grades
-- server-side using the real table the client never sees; and a
-- locked-fields column-lock (mirrors `loans_locked_fields`) so a direct
-- client write to `course_progress` can never set `certified`/`completed_on`
-- itself — only the verified RPC (or staff) can.
-- ─────────────────────────────────────────────────────────────────────────

-- 1/3: masked view — no `correct_index`. The client now reads quiz content
-- through this instead of the base table.
-- security_invoker = false (definer semantics, matching `shg_own_masked`'s
-- precedent) — the view must read the base table with the view owner's own
-- privileges, since the very next statement revokes `authenticated`'s
-- direct SELECT grant on that table entirely. A security_invoker view would
-- re-check the querying user's own table-level grant and fail once that's
-- revoked.
create or replace view public.quiz_questions_public
with (security_invoker = false) as
  select id, course_id, question, options, order_index
  from public.quiz_questions;

grant select on public.quiz_questions_public to authenticated;

-- Direct base-table SELECT is no longer needed by any client path (the
-- masked view above covers `fetchQuizQuestions`; the RPC below reads the
-- base table as its own definer, unaffected by this revoke) — revoking it
-- is what actually stops a direct REST call from requesting `correct_index`
-- explicitly; the existing RLS policy alone couldn't, since RLS is row-level
-- and has no way to hide one column from an otherwise-permitted row.
revoke select on public.quiz_questions from authenticated;

-- 2/3: column-lock — a member's own direct write to `course_progress` can
-- never change `certified`/`completed_on` from whatever they already are
-- (false/null on a fresh row); only staff or the RPC below (running as
-- security definer, bypassing RLS entirely) can actually set them.
create or replace function public.course_progress_locked_fields(p_course_id uuid, p_member_id uuid)
returns table (certified boolean, completed_on date)
language sql
security definer
stable
set search_path = public
as $$
  select cp.certified, cp.completed_on
  from public.course_progress cp
  where cp.course_id = p_course_id
    and cp.member_id = p_member_id
    and (cp.member_id = auth.uid() or public.is_staff());
$$;

revoke all on function public.course_progress_locked_fields(uuid, uuid) from public;
grant execute on function public.course_progress_locked_fields(uuid, uuid) to authenticated;

drop policy if exists "course_progress_write_self_or_staff" on public.course_progress;

create policy "course_progress_write_self_or_staff" on public.course_progress
  for all using (
    member_id = auth.uid() or is_staff()
  ) with check (
    is_staff()
    or (
      member_id = auth.uid()
      and certified = coalesce((select f.certified from public.course_progress_locked_fields(course_id, member_id) f), false)
      and completed_on is not distinct from (select f.completed_on from public.course_progress_locked_fields(course_id, member_id) f)
    )
  );

-- 3/3: server-side grading + certification RPC. Answers are positional
-- (1-indexed to match Postgres array conventions), ordered the same way
-- the client already fetches questions (`order_index`) — the client sends
-- back exactly the array of option-indices it collected, never the
-- correct answers themselves.
create or replace function public.submit_quiz_attempt(p_course_id uuid, p_answers int[])
returns table (passed boolean, score int, total int)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_correct int[];
  v_total int;
  v_score int := 0;
  v_required int;
  v_passed boolean;
begin
  select array_agg(correct_index order by order_index) into v_correct
  from public.quiz_questions
  where course_id = p_course_id;

  v_total := coalesce(array_length(v_correct, 1), 0);
  if v_total = 0 then
    raise exception 'no quiz questions for this course';
  end if;
  if array_length(p_answers, 1) is distinct from v_total then
    raise exception 'answer count (%) does not match question count (%)', array_length(p_answers, 1), v_total;
  end if;

  for i in 1..v_total loop
    if p_answers[i] = v_correct[i] then
      v_score := v_score + 1;
    end if;
  end loop;

  -- Same proportional >=2/3 threshold already used client-side in
  -- `course_quiz_page.dart`'s `requiredScoreToPass` — kept in sync here so
  -- the server's pass/fail decision matches what the UI already promises.
  v_required := ceil(v_total * 2.0 / 3);
  v_passed := v_score >= v_required;

  if v_passed then
    insert into public.course_progress (course_id, member_id, progress, certified, completed_on)
    values (p_course_id, auth.uid(), 100, true, current_date)
    on conflict (course_id, member_id) do update
      set progress = 100, certified = true, completed_on = current_date;
  end if;

  return query select v_passed, v_score, v_total;
end;
$$;

revoke all on function public.submit_quiz_attempt(uuid, int[]) from public;
grant execute on function public.submit_quiz_attempt(uuid, int[]) to authenticated;
