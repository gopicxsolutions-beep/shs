import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/training.dart' as mock;
import '../models/training.dart';
import '../services/supabase_service.dart';

/// Backed by `public.training_courses` / `public.course_progress` when
/// Supabase is configured; falls back to `lib/data/training.dart`
/// otherwise. The course catalog is public reference data.
class TrainingRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so passing a quiz would otherwise never
  // show as certified anywhere — track it here so it survives for the rest
  // of the session, mirroring AnnouncementRepository._locallyRead.
  static final Set<String> _locallyCertified = {};

  Future<List<Course>> fetchCourses() async {
    if (!_live) return mock.courses.map((c) => Course(id: c.id, title: c.title, topic: c.topic, format: c.format, duration: c.duration)).toList();
    // Platform-wide catalog shared by every SHG (see class doc comment and
    // TrainingHomePage's own note on this), not bounded by any one group's
    // size — it grows as more content is added over time. Previously had no
    // `.limit()` at all. Capped at a generous 500 rather than left
    // unbounded, matching the same defensive cap now applied to the other
    // platform-wide catalogs (marketplace products, admin user/SHG lists).
    final rows = await _client.from('training_courses').select().order('created_at').limit(500);
    return (rows as List).map((r) => Course.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Course?> fetchCourseById(String id) async {
    if (!_live) {
      final matches = mock.courses.where((c) => c.id == id);
      if (matches.isEmpty) return null;
      final c = matches.first;
      return Course(id: c.id, title: c.title, topic: c.topic, format: c.format, duration: c.duration);
    }
    final row = await _client.from('training_courses').select().eq('id', id).maybeSingle();
    return row == null ? null : Course.fromMap(row);
  }

  /// Real per-course quiz content backed by `public.quiz_questions`
  /// (migration 0041) in live mode; `lib/data/training.dart`'s
  /// `quizQuestions` map in demo mode. Ordered deterministically (by
  /// `order_index`/list position) so the same course always presents its
  /// questions in the same order.
  Future<List<QuizQuestion>> fetchQuizQuestions(String courseId) async {
    if (!_live) {
      final mockQs = mock.quizQuestions[courseId] ?? const <mock.MockQuizQuestion>[];
      return [
        for (var i = 0; i < mockQs.length; i++)
          QuizQuestion(id: '$courseId-q$i', courseId: courseId, question: mockQs[i].question, options: mockQs[i].options, correctIndex: mockQs[i].correctIndex),
      ];
    }
    // Reads the masked `quiz_questions_public` view (migration 0051), not
    // the base table — `correct_index` is never sent to the client. See
    // `submitQuiz`'s doc comment for the full write-up of why.
    final rows = await _client.from('quiz_questions_public').select().eq('course_id', courseId).order('order_index');
    return (rows as List).map((r) => QuizQuestion.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Map<String, CourseProgress>> fetchMyProgress(String? memberId) async {
    if (!_live) {
      return {
        for (final c in mock.courses)
          c.id: _locallyCertified.contains(c.id)
              ? CourseProgress(courseId: c.id, progress: 100, certified: true)
              : CourseProgress(courseId: c.id, progress: c.progress, certified: c.certified),
      };
    }
    if (memberId == null) return {};
    final rows = await _client.from('course_progress').select().eq('member_id', memberId);
    return {for (final r in rows as List) (r as Map<String, dynamic>)['course_id'] as String: CourseProgress.fromMap(r)};
  }

  Future<void> updateProgress(String courseId, String? memberId, int progress) async {
    if (!_live || memberId == null) return;
    await _client.from('course_progress').upsert({
      'course_id': courseId,
      'member_id': memberId,
      'progress': progress,
    }, onConflict: 'course_id,member_id');
  }

  /// Demo-mode-only: marks a course certified directly (no live backend to
  /// grade an attempt against there). Kept as its own method because
  /// `test/repositories/admin_dashboard_stats_staleness_test.dart` exercises
  /// it directly to simulate "a course was just passed" without going
  /// through the quiz UI. Live mode's only path to certification is
  /// `submitQuiz` below — a direct live-mode upsert setting `certified:
  /// true` is no longer even possible (RLS now rejects it; migration 0051),
  /// so this intentionally has no live-mode branch at all.
  Future<void> markCertified(String courseId, String? memberId) async {
    if (_live) return;
    _locallyCertified.add(courseId);
  }

  /// Grades a quiz attempt and, on passing, marks the course certified —
  /// the sole entry point `CourseQuizPage` should call, replacing what used
  /// to be client-side scoring (comparing answers against `correctIndex`,
  /// which shipped to the client via `fetchQuizQuestions` before the member
  /// even answered) followed by an unconditional `markCertified()` call
  /// with no score or answers sent to the server at all — a member (or any
  /// REST-savvy user) could self-certify without ever passing, an integrity
  /// gap for `AdminRepository.trainingCompletionPctFrom`'s federation-level
  /// completion metric, not just the individual's own record.
  ///
  /// In live mode this is entirely server-side via the `submit_quiz_attempt`
  /// RPC (`security definer`, migration 0051): the client sends only its
  /// answer indices, the RPC compares them against the base `quiz_questions`
  /// table's real `correct_index` (never exposed to the client — see
  /// `fetchQuizQuestions`'s doc comment) and atomically certifies on a pass.
  /// In demo mode there's no live backend to grade against, so this mirrors
  /// the old client-side comparison against the demo mock data's own
  /// `correctIndex` (still populated there — see `QuizQuestion`'s doc
  /// comment) and reuses `markCertified()` for the local-state update.
  Future<({bool passed, int score, int total})> submitQuiz(String courseId, String? memberId, List<QuizQuestion> questions, List<int> answers) async {
    if (!_live) {
      final total = questions.length;
      final score = List.generate(total, (i) => answers[i] == questions[i].correctIndex ? 1 : 0).reduce((a, b) => a + b);
      final passed = score >= requiredScoreToPass(total);
      if (passed) await markCertified(courseId, memberId);
      return (passed: passed, score: score, total: total);
    }
    final rows = await _client.rpc('submit_quiz_attempt', params: {
      'p_course_id': courseId,
      'p_answers': answers,
    }) as List;
    final row = rows.first as Map<String, dynamic>;
    return (passed: row['passed'] as bool, score: row['score'] as int, total: row['total'] as int);
  }

  Future<List<Course>> fetchCertificates(String? memberId) async {
    final progress = await fetchMyProgress(memberId);
    final courses = await fetchCourses();
    return courses.where((c) => progress[c.id]?.certified == true).toList();
  }
}
