-- Quiz has no attempt cap or cooldown at all — brute-forceable, and doubles
-- as an answer-key extraction oracle.
--
-- `submit_quiz_attempt` (0051) correctly grades server-side and never ships
-- `correct_index` to the client, but it can be called an unlimited number
-- of times with no counter, delay, or lockout, and it returns the exact
-- `score`/`total` for every attempt. A scripted caller can flip one answer
-- at a time and watch the score delta to reconstruct the entire answer key
-- without `correct_index` ever being exposed directly, and/or simply
-- brute-force-guess a short quiz (`quiz_questions_options_min_length` only
-- requires >= 2 options per question, 0041) into a guaranteed pass. Neither
-- is currently possible to detect or throttle since every attempt is
-- ungated and unlogged.
--
-- Fix: a small daily attempt counter per (course, member), same
-- insert/on-conflict/update/returning atomic-counter shape
-- `check_and_increment_ai_advisor_rate_limit` (0031) already established
-- for the AI advisor — a genuine learner gets a generous number of tries
-- to actually learn the material and pass, but a scripted key-extraction
-- attempt (which needs roughly question_count × (options_per_question - 1)
-- attempts to fully reconstruct a short quiz) is capped at a small fraction
-- of that per day, making the attack impractically slow rather than
-- instant.

create table if not exists public.quiz_attempt_counters (
  course_id uuid not null references public.training_courses (id) on delete cascade,
  member_id uuid not null,
  attempt_date date not null,
  attempt_count int not null default 0,
  primary key (course_id, member_id, attempt_date)
);

-- Same "helper table, no direct client policies, only reachable through the
-- SECURITY DEFINER function below" treatment as ai_advisor_rate_limits.
alter table public.quiz_attempt_counters enable row level security;

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
  v_max_attempts_per_day constant int := 5;
  v_attempt_count int;
begin
  insert into public.quiz_attempt_counters (course_id, member_id, attempt_date, attempt_count)
  values (p_course_id, auth.uid(), current_date, 1)
  on conflict (course_id, member_id, attempt_date)
    do update set attempt_count = quiz_attempt_counters.attempt_count + 1
  returning attempt_count into v_attempt_count;

  -- Opportunistic cleanup, same rationale as ai_advisor_rate_limits' inline
  -- sweep — no separate cron job needed for a table this cheap to prune.
  delete from public.quiz_attempt_counters where attempt_date < current_date - interval '7 days';

  if v_attempt_count > v_max_attempts_per_day then
    raise exception 'too many quiz attempts today for this course — try again tomorrow';
  end if;

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
