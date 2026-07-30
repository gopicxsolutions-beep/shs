-- Gap-hunt iteration 36: dogfooding migration 0135's own fix found a
-- CRITICAL bypass of the entire meetings-deletion lock it introduced.
--
-- 0135's `meetings_delete_staff` only checked `original_meeting_date >=
-- current_date` — the immutable anchor stamped once at INSERT — reasoning
-- that a meeting whose original schedule is still future "was never
-- actually held yet, so there is no real attendance/history to protect."
-- But `original_meeting_date` only ever protects against the CANCEL-guard
-- laundering path (0134); it says nothing about the meeting's CURRENT,
-- mutable `meeting_date`. `meetings_update_leader_or_staff`'s staff branch
-- already permits backdating `meeting_date` up to 7 days into the past and
-- setting `status = 'completed'` in the same statement (the only backdate
-- restriction it enforces is on CANCELLING, not on any other status).
--
-- Live-verified end-to-end (rolled back): created a meeting 60 days out
-- (`original_meeting_date` = +60d) → staff UPDATE backdated `meeting_date`
-- to -3d and set `status = 'completed'` (permitted) → inserted 2 real
-- `meeting_attendance` rows against it (permitted, since the now-current
-- `meeting_date` is in the past) → staff DELETE succeeded (row count = 1),
-- cascading the fabricated "completed" meeting and its 2 attendance rows
-- away with zero trace — `original_meeting_date` was still +60d the whole
-- time, so 0135's own guard never fired.
--
-- Fixed by requiring the meeting's CURRENT `meeting_date` to also still be
-- today-or-future, in addition to the immutable anchor. Closes the exact
-- exploit (backdating `meeting_date` immediately fails this new check) while
-- preserving the legitimate use case 0135 was written for — cleaning up an
-- accidentally-created future meeting, whose `meeting_date` stays future
-- until an admin actually deletes it.
drop policy if exists "meetings_delete_staff" on public.meetings;
create policy "meetings_delete_staff" on public.meetings
  for delete using (public.is_staff() and original_meeting_date >= current_date and meeting_date >= current_date);

-- Also 2 real gaps in the Training/Quiz module, found by a fresh audit:
--
-- 1. [HIGH] A course's last remaining `quiz_questions` row could be deleted
--    one-by-one with no guard, silently making an already-listed,
--    already-certifying course permanently uncompletable — live-confirmed:
--    course b3000000-...-0002 currently has 0 questions but 2 members
--    already certified for it, and `submit_quiz_attempt` now raises
--    "no quiz questions for this course" for anyone else attempting it.
--    Fixed with a guard that blocks deleting a course's last question
--    while the course itself still exists in the catalog (a real DELETE
--    FROM training_courses cascading its questions away is unaffected,
--    since the parent row is already gone by the time the cascade reaches
--    its children — see the `exists` check below).
create or replace function public.quiz_questions_block_last_delete()
returns trigger
language plpgsql
as $$
begin
  if exists (select 1 from public.training_courses where id = old.course_id)
     and not exists (select 1 from public.quiz_questions where course_id = old.course_id and id <> old.id)
  then
    raise exception 'cannot delete the last quiz question for a course still in the catalog — delete the course itself, or add a replacement question first';
  end if;
  return old;
end;
$$;

drop trigger if exists quiz_questions_block_last_delete on public.quiz_questions;
create trigger quiz_questions_block_last_delete
  before delete on public.quiz_questions
  for each row execute function public.quiz_questions_block_last_delete();

-- 2. [MEDIUM] `submit_quiz_attempt`'s `on conflict do update` unconditionally
--    overwrote `completed_on = current_date` on every passing re-attempt,
--    even for a member already certified — live-confirmed: a member
--    already certified on 2026-06-20 who simply retook and re-passed the
--    same quiz had `completed_on` silently jump to today, corrupting her
--    own certificate date and any federation-level "when was this
--    completed" reporting, for the cost of just one of her 5 daily
--    attempts. Fixed to only stamp `completed_on` the first time a member
--    is certified for a course; a re-pass keeps the original date.
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
  if not public.profile_is_active(auth.uid()) then
    raise exception 'your account has been deactivated';
  end if;

  insert into public.quiz_attempt_counters (course_id, member_id, attempt_date, attempt_count)
  values (p_course_id, auth.uid(), current_date, 1)
  on conflict (course_id, member_id, attempt_date)
    do update set attempt_count = quiz_attempt_counters.attempt_count + 1
  returning attempt_count into v_attempt_count;

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
      set progress = 100,
          certified = true,
          completed_on = case when public.course_progress.certified then public.course_progress.completed_on else current_date end;
  end if;

  return query select v_passed, v_score, v_total;
end;
$$;
