import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/training.dart' as mock;
import '../models/training.dart';
import '../services/supabase_service.dart';

/// Thrown by [TrainingRepository.submitQuiz] when `submit_quiz_attempt`
/// (migration 0070) rejects the attempt because the member has already
/// used up today's attempt cap for this course.
class QuizAttemptLimitExceededException implements Exception {
  const QuizAttemptLimitExceededException();
}

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

  // Admin catalog CRUD (courses + their quiz questions) — same idea as
  // SchemeRepository's _locallyAdded/_locallyDeleted/_locallyUpdated
  // Schemes fields: adding/editing/deleting would otherwise silently revert
  // the moment the catalog reloads, since demo mode has no backing table.
  // Quiz questions are keyed by course id for "added" (a fresh list per
  // course) but by question id for "updated"/"deleted", mirroring how
  // fetchQuizQuestions synthesizes a stable-per-call id
  // (`'$courseId-q$i'`) for pre-existing mock questions.
  static final List<Course> _locallyAddedCourses = [];
  static final Set<String> _locallyDeletedCourses = {};
  static final Map<String, Course> _locallyUpdatedCourses = {};
  static final Map<String, List<QuizQuestion>> _locallyAddedQuizQuestions = {};
  static final Set<String> _locallyDeletedQuizQuestionIds = {};
  static final Map<String, QuizQuestion> _locallyUpdatedQuizQuestions = {};

  Future<List<Course>> fetchCourses() async {
    if (!_live) {
      final base = mock.courses
          .where((c) => !_locallyDeletedCourses.contains(c.id))
          .map((c) => _locallyUpdatedCourses[c.id] ?? Course(id: c.id, title: c.title, topic: c.topic, format: c.format, duration: c.duration, videoUrl: c.videoUrl));
      return [...base, ..._locallyAddedCourses];
    }
    // Platform-wide catalog shared by every SHG (see class doc comment and
    // TrainingHomePage's own note on this), not bounded by any one group's
    // size — it grows as more content is added over time. Previously had no
    // `.limit()` at all. Capped at a generous 500 rather than left
    // unbounded, matching the same defensive cap now applied to the other
    // platform-wide catalogs (marketplace products, admin user/SHG lists).
    final rows = await _client.from('training_courses').select().order('created_at').limit(500);
    return (rows as List).map((r) => Course.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Admin-only: creates a new course in the platform-wide catalog. RLS
  /// (`training_courses_write_staff`) restricts the live-mode insert to
  /// crp/clf/admin — see `admin_training_courses_page.dart`'s own UI-level
  /// gate, which matches that same staff scope (not narrowed to admin-only).
  Future<Course> createCourse({required String title, required String topic, required String format, String? duration, String? videoUrl}) async {
    if (!_live) {
      final course = Course(id: 'local-course-${_locallyAddedCourses.length}-${title.hashCode}', title: title, topic: topic, format: format, duration: duration, videoUrl: videoUrl);
      _locallyAddedCourses.add(course);
      return course;
    }
    final row = await _client.from('training_courses').insert({'title': title, 'topic': topic, 'format': format, 'duration': duration, 'video_url': videoUrl}).select().single();
    return Course.fromMap(row);
  }

  Future<void> updateCourse(String id, {required String title, required String topic, required String format, String? duration, String? videoUrl}) async {
    if (!_live) {
      final updated = Course(id: id, title: title, topic: topic, format: format, duration: duration, videoUrl: videoUrl);
      final addedIdx = _locallyAddedCourses.indexWhere((c) => c.id == id);
      if (addedIdx != -1) {
        _locallyAddedCourses[addedIdx] = updated;
      } else {
        _locallyUpdatedCourses[id] = updated;
      }
      return;
    }
    await _client.from('training_courses').update({'title': title, 'topic': topic, 'format': format, 'duration': duration, 'video_url': videoUrl}).eq('id', id);
  }

  /// Uploads a picked video's bytes to the public `training-videos` bucket
  /// (migration 0115) and returns its permanent public URL — same shape as
  /// `MarketplaceRepository.uploadProductImage`. Unlike that bucket's
  /// per-seller folder convention, writes here are gated purely by
  /// `public.is_staff()` (matching `training_courses_write_staff`'s own
  /// scope), not by folder ownership, so the path doesn't need a per-user
  /// prefix. Public-read (not a signed URL) because a video can play for
  /// much longer than a signed URL's validity window — a short-lived URL
  /// would risk expiring mid-playback.
  Future<String> uploadCourseVideo({required Uint8List bytes, required String fileName, required String contentType}) async {
    final path = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    await _client.storage.from('training-videos').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
    return _client.storage.from('training-videos').getPublicUrl(path);
  }

  /// Deleting a course still cascades to its own quiz question bank
  /// (`quiz_questions.course_id on delete cascade`, migration 0041) — real
  /// content removal, matching this repository's course-catalog scope (no
  /// "archive instead of delete" concept exists here today). It no longer
  /// cascades to member progress: `course_progress.course_id` was changed
  /// to `on delete restrict` (round 187's `0091`) specifically so deleting
  /// a course can never silently destroy a member's already-earned
  /// certification history — once any member has engaged with a course at
  /// all, this call fails with a foreign-key-violation instead (surfaced
  /// to the admin via `AdminTrainingCoursesPage`'s existing generic error
  /// toast). There is currently no admin path to force-delete or archive a
  /// course past that point — a real, deliberately-deferred gap, not an
  /// oversight.
  Future<void> deleteCourse(String id) async {
    if (!_live) {
      _locallyAddedCourses.removeWhere((c) => c.id == id);
      _locallyDeletedCourses.add(id);
      return;
    }
    await _client.from('training_courses').delete().eq('id', id);
  }

  Future<Course?> fetchCourseById(String id) async {
    if (!_live) {
      final matches = mock.courses.where((c) => c.id == id);
      if (matches.isEmpty) return null;
      final c = matches.first;
      return Course(id: c.id, title: c.title, topic: c.topic, format: c.format, duration: c.duration, videoUrl: c.videoUrl);
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
      final base = [
        for (var i = 0; i < mockQs.length; i++)
          if (!_locallyDeletedQuizQuestionIds.contains('$courseId-q$i'))
            _locallyUpdatedQuizQuestions['$courseId-q$i'] ??
                QuizQuestion(id: '$courseId-q$i', courseId: courseId, question: mockQs[i].question, options: mockQs[i].options, correctIndex: mockQs[i].correctIndex),
      ];
      return [...base, ...?_locallyAddedQuizQuestions[courseId]];
    }
    // Reads the masked `quiz_questions_public` view (migration 0051), not
    // the base table — `correct_index` is never sent to the client. See
    // `submitQuiz`'s doc comment for the full write-up of why.
    final rows = await _client.from('quiz_questions_public').select().eq('course_id', courseId).order('order_index');
    return (rows as List).map((r) => QuizQuestion.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Admin-editor-only counterpart to [fetchQuizQuestions]: reads the BASE
  /// `quiz_questions` table (not the masked view) so an existing question's
  /// `correctIndex` can be shown when editing it — `fetchQuizQuestions`
  /// deliberately never exposes that column to any caller, by design (see
  /// its own doc comment), which is exactly right for a member taking a
  /// quiz but wrong for an admin authoring one.
  ///
  /// Requires migration `0060_quiz_questions_staff_base_table_read.sql` to
  /// be deployed — until then, the base-table query legitimately returns
  /// zero rows for every caller (the table-level SELECT grant for
  /// `authenticated` is still fully revoked; see that migration's own
  /// comment), which is indistinguishable here from "this course genuinely
  /// has no questions yet". Rather than surface that ambiguity as a false
  /// empty state, fall back to the masked view so the admin page still
  /// lists real existing questions (`correctIndex` just comes back null,
  /// same as any other caller) instead of hiding them.
  Future<List<QuizQuestion>> fetchQuizQuestionsForAdmin(String courseId) async {
    if (!_live) return fetchQuizQuestions(courseId);
    final rows = await _client.from('quiz_questions').select().eq('course_id', courseId).order('order_index');
    if (rows.isEmpty) return fetchQuizQuestions(courseId);
    return rows.map((r) => QuizQuestion.fromMap(r)).toList();
  }

  /// `options` must have at least 2 entries and `correctIndex` must be a
  /// valid index into it — enforced client-side by the admin form, and
  /// independently by the live database
  /// (`quiz_questions_options_min_length`/`quiz_questions_correct_index_in_range`,
  /// migration 0041), so a malformed write fails loudly rather than
  /// silently corrupting a course's quiz.
  Future<QuizQuestion> createQuizQuestion({required String courseId, required String question, required List<String> options, required int correctIndex}) async {
    if (!_live) {
      final q = QuizQuestion(
        id: 'local-question-${(_locallyAddedQuizQuestions[courseId]?.length ?? 0)}-${question.hashCode}',
        courseId: courseId,
        question: question,
        options: options,
        correctIndex: correctIndex,
      );
      (_locallyAddedQuizQuestions[courseId] ??= []).add(q);
      return q;
    }
    // Was never sent, so every admin-added question defaulted to the same
    // order_index (0, migration 0041's column default) — a course with
    // multiple questions had them all tied. Both the display fetch (this
    // file's `.order('order_index')`) and the server's independent grading
    // re-query (`submit_quiz_attempt`'s `array_agg(... order by
    // order_index)`) sort by this same non-unique key with no tiebreaker,
    // so the two separately-executed queries have no guaranteed agreement
    // on tie order — a real risk of a member's answer being graded against
    // the wrong question. Migration 0089 added a `unique (course_id,
    // order_index)` constraint precisely so a collision here fails loudly
    // (a legitimate concurrent-add race) rather than silently creating a
    // new tie.
    final existing = await _client.from('quiz_questions').select('order_index').eq('course_id', courseId).order('order_index', ascending: false).limit(1);
    final nextOrderIndex = existing.isEmpty ? 0 : (existing.first['order_index'] as int) + 1;
    final row = await _client.from('quiz_questions').insert({'course_id': courseId, 'question': question, 'options': options, 'correct_index': correctIndex, 'order_index': nextOrderIndex}).select().single();
    return QuizQuestion.fromMap(row);
  }

  Future<void> updateQuizQuestion(String id, {required String courseId, required String question, required List<String> options, required int correctIndex}) async {
    if (!_live) {
      final updated = QuizQuestion(id: id, courseId: courseId, question: question, options: options, correctIndex: correctIndex);
      final addedList = _locallyAddedQuizQuestions[courseId];
      final addedIdx = addedList?.indexWhere((q) => q.id == id) ?? -1;
      if (addedList != null && addedIdx != -1) {
        addedList[addedIdx] = updated;
      } else {
        _locallyUpdatedQuizQuestions[id] = updated;
      }
      return;
    }
    await _client.from('quiz_questions').update({'question': question, 'options': options, 'correct_index': correctIndex}).eq('id', id);
  }

  Future<void> deleteQuizQuestion(String id, {required String courseId}) async {
    if (!_live) {
      _locallyAddedQuizQuestions[courseId]?.removeWhere((q) => q.id == id);
      _locallyDeletedQuizQuestionIds.add(id);
      return;
    }
    await _client.from('quiz_questions').delete().eq('id', id);
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
    try {
      final rows = await _client.rpc('submit_quiz_attempt', params: {
        'p_course_id': courseId,
        'p_answers': answers,
      }) as List;
      final row = rows.first as Map<String, dynamic>;
      return (passed: row['passed'] as bool, score: row['score'] as int, total: row['total'] as int);
    } on PostgrestException catch (e) {
      if (e.message.contains('too many quiz attempts')) throw const QuizAttemptLimitExceededException();
      rethrow;
    }
  }

  Future<List<Course>> fetchCertificates(String? memberId) async {
    final progress = await fetchMyProgress(memberId);
    final courses = await fetchCourses();
    return courses.where((c) => progress[c.id]?.certified == true).toList();
  }
}
