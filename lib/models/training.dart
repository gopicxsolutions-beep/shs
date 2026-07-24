/// Mirrors a row in `public.training_courses`.
class Course {
  final String id;
  final String title;
  final String topic;
  final String format; // Video | PDF | Audio
  final String? duration;

  const Course({required this.id, required this.title, required this.topic, required this.format, this.duration});

  factory Course.fromMap(Map<String, dynamic> map) => Course(
        id: map['id'] as String,
        title: map['title'] as String,
        topic: map['topic'] as String,
        format: map['format'] as String,
        duration: map['duration'] as String?,
      );
}

/// The number of correct answers required to pass a quiz of [total]
/// questions. Proportional to the original fixed 3-question quiz's ≥2/3
/// threshold (now that real per-course content means the question count
/// varies course to course) — rounded UP so a longer quiz never becomes
/// easier to pass than the original 2-out-of-3 bar. Shared between
/// `CourseQuizPage` (display) and `TrainingRepository.submitQuiz`'s demo-mode
/// branch (grading) — and mirrored server-side in the `submit_quiz_attempt`
/// RPC (migration 0051) for live mode, so all three stay in exact agreement
/// on what counts as a pass.
int requiredScoreToPass(int total) => (total * 2 / 3).ceil();

/// Mirrors a row in `public.quiz_questions` — one multiple-choice question
/// belonging to a specific course's certification quiz.
///
/// [correctIndex] is only ever populated in demo mode (from
/// `lib/data/training.dart`'s local mock content, used for demo mode's own
/// client-side "preview" grading — there is no live backend there to verify
/// against). In live mode, questions are fetched from
/// `public.quiz_questions_public`, a view that deliberately excludes
/// `correct_index` — the answer key is graded server-side by the
/// `submit_quiz_attempt` RPC and is never sent to the client at all (see
/// `TrainingRepository.submitQuiz`'s doc comment for why: the base table's
/// `correct_index` used to ship to the client before the member ever
/// answered a single question, and grading/certification then trusted
/// whatever the client claimed with zero server-side verification).
class QuizQuestion {
  final String id;
  final String courseId;
  final String question;
  final List<String> options;
  final int? correctIndex;

  const QuizQuestion({
    required this.id,
    required this.courseId,
    required this.question,
    required this.options,
    this.correctIndex,
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) => QuizQuestion(
        id: map['id'] as String,
        courseId: map['course_id'] as String,
        question: map['question'] as String,
        options: (map['options'] as List).map((e) => e as String).toList(),
        correctIndex: map['correct_index'] as int?,
      );
}

/// Mirrors a row in `public.course_progress` for one member/course pair.
class CourseProgress {
  final String courseId;
  final int progress;
  final bool certified;
  final DateTime? completedOn;

  const CourseProgress({required this.courseId, required this.progress, required this.certified, this.completedOn});

  factory CourseProgress.fromMap(Map<String, dynamic> map) => CourseProgress(
        courseId: map['course_id'] as String,
        progress: map['progress'] as int? ?? 0,
        certified: map['certified'] as bool? ?? false,
        completedOn: map['completed_on'] != null ? DateTime.parse(map['completed_on'] as String) : null,
      );
}
