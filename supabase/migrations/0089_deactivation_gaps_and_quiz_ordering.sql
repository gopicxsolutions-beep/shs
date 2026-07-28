-- Gap-hunt round 185 (iteration 13): three more places the "deactivated
-- member" concept (0083) never actually got enforced, all found by
-- dogfooding/auditing prior rounds' own work, plus an unrelated quiz data-
-- integrity gap found by the Schemes/Training audit.

-- ─────────────────────────────────────────────────────────────────────────
-- 1. savings_entries / livelihood_activities: 0087 added
--    `profile_is_active(member_id)` to the LEADER branch only. The
--    `is_staff()` branch in both policies is a bare, unconditional OR —
--    completely untouched by 0087 despite that migration's own stated goal
--    ("close the deactivated-member entry lockout gap"). A crp/clf/admin
--    account can still create a savings entry or a livelihood activity for
--    an already-deactivated member today. Fix: require
--    `profile_is_active(member_id)` on the staff branch too, without
--    touching the status/date lock that branch deliberately sits outside
--    of (staff corrections legitimately need that latitude — this is
--    solely about the target member's account, not about what fields
--    staff may set).
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "savings_insert_self_leader_or_staff" on public.savings_entries;

create policy "savings_insert_self_leader_or_staff" on public.savings_entries
  for insert with check (
    (public.is_staff() and public.profile_is_active(member_id))
    or (
      status = 'pending'
      and entry_date = current_date
      and created_at = now()
      and (
        (member_id = auth.uid() and shg_id = public.current_shg_id())
        or (
          shg_id = public.current_shg_id()
          and public.current_role() = 'leader'
          and public.profile_shg_id(member_id) = shg_id
          and public.profile_is_active(member_id)
        )
      )
    )
  );

drop policy if exists "livelihood_insert_self_leader_or_staff" on public.livelihood_activities;

create policy "livelihood_insert_self_leader_or_staff" on public.livelihood_activities
  for insert with check (
    (
      (member_id = auth.uid() and shg_id = public.current_shg_id())
      or (
        shg_id = public.current_shg_id()
        and public.current_role() = 'leader'
        and public.profile_shg_id(member_id) = shg_id
        and public.profile_is_active(member_id)
      )
      or (public.is_staff() and public.profile_is_active(member_id))
    )
    and status = 'planned'
    and revenue = 0
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 2. scheme_applications_insert_self (0074): self-insert-only, bare
--    `member_id = auth.uid()` with no `is_active` check anywhere — a
--    deactivated member's still-valid session token can submit a fresh
--    government-scheme application.
-- ─────────────────────────────────────────────────────────────────────────

drop policy if exists "scheme_applications_insert_self" on public.scheme_applications;

create policy "scheme_applications_insert_self" on public.scheme_applications
  for insert with check (
    member_id = auth.uid()
    and public.profile_is_active(member_id)
    and status = 'applied'
    and applied_on = current_date
    and exists (
      select 1 from public.schemes s
      where s.id = scheme_id
        and (s.deadline is null or s.deadline >= current_date)
    )
    and public.scheme_eligibility_met(scheme_id, member_id)
  );

-- ─────────────────────────────────────────────────────────────────────────
-- 3. submit_quiz_attempt (0070): `security definer`, bypasses RLS
--    entirely, and never checked `is_active` in its own body — a
--    deactivated member's still-valid session can keep certifying courses
--    after deactivation. Checked first, before even incrementing the daily
--    attempt counter, so a blocked call doesn't burn one of the member's 5
--    daily attempts.
-- ─────────────────────────────────────────────────────────────────────────

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
      set progress = 100, certified = true, completed_on = current_date;
  end if;

  return query select v_passed, v_score, v_total;
end;
$$;

-- ─────────────────────────────────────────────────────────────────────────
-- 4. quiz_questions.order_index: every admin-added question defaults to 0
--    (`TrainingRepository.createQuizQuestion` never sent an explicit
--    value) — a course with multiple admin-added questions has every row
--    tied at order_index=0. The client's display fetch and the server's
--    independent grading re-query (submit_quiz_attempt, above) both sort
--    by this same non-unique key with no tiebreaker, so the two separately
--    executed queries have no guaranteed agreement on tie order — a real
--    risk of grading a member's answer against the wrong question. Fixed
--    at the Dart layer (createQuizQuestion now computes the next value);
--    this backfills every existing tied row to a stable, deterministic
--    order (oldest-created first) and adds a uniqueness constraint so a
--    future collision fails loudly (a legitimate concurrent-add race)
--    instead of silently reintroducing a tie.
-- ─────────────────────────────────────────────────────────────────────────

with ranked as (
  select id, row_number() over (partition by course_id order by created_at, id) - 1 as new_order_index
  from public.quiz_questions
)
update public.quiz_questions q
set order_index = ranked.new_order_index
from ranked
where q.id = ranked.id
  and q.order_index is distinct from ranked.new_order_index;

alter table public.quiz_questions add constraint quiz_questions_course_id_order_index_key unique (course_id, order_index);
