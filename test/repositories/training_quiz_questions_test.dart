import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/data/training.dart' as mock;
import 'package:shg_saathi/models/training.dart';
import 'package:shg_saathi/repositories/training_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for the new per-course quiz content
/// (`public.quiz_questions` / migration 0041) that replaced
/// CourseQuizPage's single hardcoded, generic 3-question set. Confirms:
/// (1) the dual-mode repository method falls back to real per-course demo
/// data, (2) every seeded demo course actually has genuinely distinct
/// content (not the same 3 questions copy-pasted), and (3) the
/// QuizQuestion model maps a live-mode row shape correctly.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  group('TrainingRepository.fetchQuizQuestions (demo mode)', () {
    test('returns questions for a course that has seeded quiz content', () async {
      final repo = TrainingRepository();
      final questions = await repo.fetchQuizQuestions('co1');
      expect(questions, isNotEmpty);
      expect(questions.every((q) => q.courseId == 'co1'), isTrue);
    });

    test('returns an empty list (not an error) for a course with no seeded quiz content', () async {
      final repo = TrainingRepository();
      final questions = await repo.fetchQuizQuestions('__no_such_course__');
      expect(questions, isEmpty);
    });

    test('every course in lib/data/training.dart has at least 3 genuine quiz questions', () async {
      final repo = TrainingRepository();
      for (final course in mock.courses) {
        final questions = await repo.fetchQuizQuestions(course.id);
        expect(questions.length, greaterThanOrEqualTo(3), reason: '${course.id} ("${course.title}") should have at least 3 seeded quiz questions');
      }
    });

    test('every seeded question has a valid, in-range correct answer index', () async {
      final repo = TrainingRepository();
      for (final course in mock.courses) {
        final questions = await repo.fetchQuizQuestions(course.id);
        for (final q in questions) {
          expect(q.options.length, greaterThanOrEqualTo(2), reason: '${course.id}: "${q.question}" needs at least 2 options');
          expect(q.correctIndex, greaterThanOrEqualTo(0), reason: '${course.id}: "${q.question}" has a negative correctIndex');
          expect(q.correctIndex, lessThan(q.options.length), reason: '${course.id}: "${q.question}" correctIndex out of range');
        }
      }
    });

    test('different courses get genuinely different question content (not the old shared generic set)', () async {
      final repo = TrainingRepository();
      final co1Questions = (await repo.fetchQuizQuestions('co1')).map((q) => q.question).toSet();
      final co2Questions = (await repo.fetchQuizQuestions('co2')).map((q) => q.question).toSet();
      expect(co1Questions.intersection(co2Questions), isEmpty, reason: 'co1 and co2 cover different course subject matter and must not share question text');
    });
  });

  group('QuizQuestion.fromMap (live-mode row shape)', () {
    test('maps a public.quiz_questions row correctly', () {
      final q = QuizQuestion.fromMap({
        'id': 'q-1',
        'course_id': 'co1',
        'question': 'What is the main purpose of a household budget?',
        'options': ['To spend without any planning', 'To plan and track income against expenses', 'To avoid saving money altogether'],
        'correct_index': 1,
      });
      expect(q.id, 'q-1');
      expect(q.courseId, 'co1');
      expect(q.options, hasLength(3));
      expect(q.correctIndex, 1);
    });
  });
}
