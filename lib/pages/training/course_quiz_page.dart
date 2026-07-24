import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/training.dart';
import '../../repositories/training_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class _QuizData {
  final Course course;
  final List<QuizQuestion> questions;
  const _QuizData(this.course, this.questions);
}

/// Real, per-course quiz content fetched from `public.quiz_questions`
/// (`TrainingRepository.fetchQuizQuestions`) in live mode, or
/// `lib/data/training.dart`'s `quizQuestions` map in demo mode — no longer
/// the one generic hardcoded question set shared by every course. Passing
/// ≥[requiredScoreToPass] of the course's own questions marks it certified.
class CourseQuizPage extends StatefulWidget {
  final String courseId;
  const CourseQuizPage({super.key, required this.courseId});
  @override
  State<CourseQuizPage> createState() => _CourseQuizPageState();
}

class _CourseQuizPageState extends State<CourseQuizPage> {
  final _repo = TrainingRepository();
  List<int?> _answers = [];
  bool _submitting = false;

  Future<void> _submit(List<QuizQuestion> questions) async {
    setState(() => _submitting = true);
    final appState = context.read<AppState>();
    try {
      // Grading (and, on a pass, certification) now happens inside
      // `submitQuiz` itself — server-side via the `submit_quiz_attempt` RPC
      // in live mode, so the client never decides its own pass/fail and
      // never needs to have seen the correct answers beforehand. See
      // `TrainingRepository.submitQuiz`'s doc comment for the full write-up
      // of the self-certification gap this replaces.
      final result = await _repo.submitQuiz(widget.courseId, appState.profile?.id, questions, _answers.cast<int>());
      if (!result.passed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.courseQuizScoreResult(result.score, result.total))));
        }
        return;
      }
      if (mounted) {
        // Navigate first, then show on the captured messenger — showing
        // before navigating drops the SnackBar, since context.go() replaces
        // this page's Scaffold before it ever gets a frame to render.
        final messenger = ScaffoldMessenger.of(context);
        final l10n = AppLocalizations.of(context)!;
        context.go(Paths.trainingDetail(widget.courseId));
        messenger.showSnackBar(
          SnackBar(content: Text(SupabaseService.isConfigured ? l10n.courseQuizPassed : l10n.courseQuizPassedDemoMode)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.courseQuizSaveError)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: PageHeader(title: l10n.courseQuizTitle),
      // Unlike CourseDetailPage (the only in-app link to this page, which
      // guards on fetchCourseById returning null), a direct URL visit (e.g.
      // #/app/training/does-not-exist/quiz) skipped that check entirely —
      // guard on the course's own existence first, mirroring every other
      // :id detail page's AppEmptyState pattern, before ever fetching quiz
      // content for a course that doesn't exist.
      body: AppAsyncBuilder<_QuizData?>(
        future: () async {
          final course = await _repo.fetchCourseById(widget.courseId);
          if (course == null) return null;
          final questions = await _repo.fetchQuizQuestions(widget.courseId);
          return _QuizData(course, questions);
        },
        builder: (context, data) {
          if (data == null) {
            return AppEmptyState(icon: Icons.error_outline_rounded, message: l10n.courseQuizNotFound);
          }
          if (data.questions.isEmpty) {
            // A real (not-yet-authored) course whose staff/admin hasn't
            // added quiz questions yet — every demo course ships with a
            // seeded set, so this is a live-mode-only edge case.
            return AppEmptyState(icon: Icons.quiz_outlined, message: l10n.courseQuizNoQuizAvailable);
          }
          // Lazily size _answers to this course's actual question count the
          // first time data resolves. Guarded on a length mismatch (rather
          // than unconditionally reassigning) so this doesn't wipe the
          // learner's in-progress answers on every rebuild this State
          // triggers (e.g. each radio-button tap calls setState here).
          if (_answers.length != data.questions.length) {
            _answers = List<int?>.filled(data.questions.length, null);
          }
          return _buildQuiz(context, data.questions);
        },
      ),
    );
  }

  Widget _buildQuiz(BuildContext context, List<QuizQuestion> questions) {
    final l10n = AppLocalizations.of(context)!;
    final allAnswered = _answers.every((a) => a != null);
    return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var qi = 0; qi < questions.length; qi++) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${qi + 1}. ${questions[qi].question}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  RadioGroup<int>(
                    groupValue: _answers[qi],
                    onChanged: (v) => setState(() => _answers[qi] = v),
                    child: Column(
                      children: [
                        for (var oi = 0; oi < questions[qi].options.length; oi++)
                          RadioListTile<int>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: oi,
                            activeColor: Brand.c600,
                            title: Text(questions[qi].options[oi], style: AppTheme.sans(12)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          AppButton(
            label: _submitting ? l10n.courseQuizSubmitting : l10n.courseQuizSubmitButton,
            fullWidth: true,
            size: ButtonSize.lg,
            onPressed: allAnswered && !_submitting ? () => _submit(questions) : null,
          ),
        ],
      );
  }
}
