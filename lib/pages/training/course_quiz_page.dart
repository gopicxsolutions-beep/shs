import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../repositories/training_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class _Question {
  final String text;
  final List<String> options;
  final int correctIndex;
  const _Question(this.text, this.options, this.correctIndex);
}

/// A small generic quiz (not tied to specific course content — there's no
/// quiz-content table in the schema yet). Passing ≥2/3 marks the course
/// certified. This is a deliberate placeholder, not a real course-specific
/// assessment engine — see docs/DEVELOPMENT_PROGRESS.md.
class CourseQuizPage extends StatefulWidget {
  final String courseId;
  const CourseQuizPage({super.key, required this.courseId});
  @override
  State<CourseQuizPage> createState() => _CourseQuizPageState();
}

class _CourseQuizPageState extends State<CourseQuizPage> {
  final _repo = TrainingRepository();
  final List<int?> _answers = [null, null, null];
  bool _submitting = false;

  static const _questions = [
    _Question('Why is it important to save regularly in an SHG?', ['It builds a financial cushion for the group', 'It has no real benefit', 'It is only for the leader'], 0),
    _Question('What should you do before taking a loan?', ['Understand the repayment terms and EMI', 'Ignore the interest rate', 'Borrow as much as possible'], 0),
    _Question('Who benefits from accurate meeting records?', ['The whole SHG, for transparency', 'No one', 'Only the CRP'], 0),
  ];

  Future<void> _submit() async {
    final score = List.generate(_questions.length, (i) => _answers[i] == _questions[i].correctIndex ? 1 : 0).reduce((a, b) => a + b);
    final passed = score >= 2;
    if (!passed) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You scored $score/${_questions.length}. Try again to pass.')));
      return;
    }
    setState(() => _submitting = true);
    final appState = context.read<AppState>();
    try {
      await _repo.markCertified(widget.courseId, appState.profile?.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passed! Certificate earned.')));
        context.go(Paths.trainingDetail(widget.courseId));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAnswered = _answers.every((a) => a != null);
    return Scaffold(
      appBar: const PageHeader(title: 'Course Quiz'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var qi = 0; qi < _questions.length; qi++) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${qi + 1}. ${_questions[qi].text}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  RadioGroup<int>(
                    groupValue: _answers[qi],
                    onChanged: (v) => setState(() => _answers[qi] = v),
                    child: Column(
                      children: [
                        for (var oi = 0; oi < _questions[qi].options.length; oi++)
                          RadioListTile<int>(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            value: oi,
                            activeColor: Brand.c600,
                            title: Text(_questions[qi].options[oi], style: AppTheme.sans(12)),
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
            label: _submitting ? 'Submitting…' : 'Submit Quiz',
            fullWidth: true,
            size: ButtonSize.lg,
            onPressed: allAnswered && !_submitting && SupabaseService.isConfigured ? _submit : null,
          ),
        ],
      ),
    );
  }
}
