-- Course quiz content was previously a single hardcoded, generic 3-question
-- set shared by every course (`CourseQuizPage._questions` in
-- `lib/pages/training/course_quiz_page.dart`) — never tied to the specific
-- course a member was actually being certified on, because there was no
-- quiz-content table in the schema at all. This adds one: `quiz_questions`,
-- a straightforward one-question-per-row table scoped to a single
-- `training_courses` row, mirroring `training_courses` itself for RLS shape
-- (public read for any authenticated user, staff/admin-only write) — no new
-- helper needed, reusing `public.is_staff()` from 0002.
--
-- `order_index` gives deterministic question ordering per course (relying on
-- `created_at` alone doesn't guarantee stable ordering for rows inserted in
-- the same batch/transaction, which is exactly how a course's question set
-- is likely to be authored).
--
-- `correct_index` is validated against the actual `options` array length at
-- write time via a check constraint, so a staff-authored question can never
-- reference a non-existent option.

create table public.quiz_questions (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.training_courses (id) on delete cascade,
  question text not null,
  options text[] not null,
  correct_index int not null,
  order_index int not null default 0,
  created_at timestamptz not null default now(),
  constraint quiz_questions_options_min_length check (array_length(options, 1) >= 2),
  constraint quiz_questions_correct_index_in_range check (correct_index >= 0 and correct_index < array_length(options, 1))
);

create index quiz_questions_course_id_idx on public.quiz_questions (course_id, order_index);

alter table public.quiz_questions enable row level security;

-- Any authenticated user can read a course's quiz questions — same as
-- training_courses_select_all; the quiz is part of the public course
-- catalog, not per-SHG or per-member scoped data.
create policy "quiz_questions_select_all" on public.quiz_questions
  for select using (auth.role() = 'authenticated');

-- Only staff/admin can author quiz content, same as training_courses_write_staff.
create policy "quiz_questions_write_staff" on public.quiz_questions
  for all using (public.is_staff()) with check (public.is_staff());
