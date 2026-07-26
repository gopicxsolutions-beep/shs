import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/training.dart';
import '../../models/types.dart';
import '../../repositories/training_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class AdminTrainingQuizPage extends StatefulWidget {
  final String courseId;
  // Passed via GoRoute `extra` from AdminTrainingCoursesPage's own already-
  // loaded list, purely to avoid an extra fetch just to show a title in the
  // app bar — null if this route was reached directly (e.g. a deep link),
  // in which case the app bar falls back to a generic title rather than
  // fetching the course just for its name.
  final String? courseTitle;
  const AdminTrainingQuizPage({super.key, required this.courseId, this.courseTitle});
  @override
  State<AdminTrainingQuizPage> createState() => _AdminTrainingQuizPageState();
}

/// Per-course quiz question management, reached from
/// `AdminTrainingCoursesPage`. A course with zero quiz questions is
/// reachable by members but `submit_quiz_attempt` (migration 0051) raises
/// "no quiz questions for this course" the moment anyone tries to take
/// it — so this page isn't optional polish, it's what makes a
/// freshly-admin-created course actually usable end to end.
///
/// Editing an existing question's correct answer degrades gracefully when
/// migration `0060_quiz_questions_staff_base_table_read.sql` hasn't been
/// deployed yet: [TrainingRepository.fetchQuizQuestionsForAdmin] falls back
/// to the masked view in that case, which never carries `correctIndex` —
/// this page shows [AppLocalizations.adminTrainingQuizCorrectAnswerNotReadableNotice]
/// and requires re-picking the answer rather than silently guessing one or
/// blocking edits entirely.
class _AdminTrainingQuizPageState extends State<AdminTrainingQuizPage> {
  final _repo = TrainingRepository();
  final GlobalKey<AppAsyncBuilderState<List<QuizQuestion>>> _key = GlobalKey();
  final _question = TextEditingController();
  List<TextEditingController> _optionControllers = [];
  int? _correctIndex;
  bool _correctAnswerUnreadable = false;
  bool _busy = false;

  @override
  void dispose() {
    _question.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _resetOptions(List<String> seed) {
    for (final c in _optionControllers) {
      c.dispose();
    }
    _optionControllers = seed.map((s) => TextEditingController(text: s)).toList();
  }

  List<Widget> _formFields(StateSetter setDialogState, AppLocalizations l10n) => [
        TextField(controller: _question, maxLength: 300, maxLines: 2, decoration: InputDecoration(hintText: l10n.adminTrainingQuizQuestionHint)),
        const SizedBox(height: 12),
        if (_correctAnswerUnreadable) ...[
          Text(l10n.adminTrainingQuizCorrectAnswerNotReadableNotice, style: AppTheme.sans(11, color: Accent.amber600)),
          const SizedBox(height: 8),
        ],
        Text(l10n.adminTrainingQuizCorrectAnswerLabel, style: AppTheme.sans(11, weight: FontWeight.w700, color: Neutral.c600)),
        for (var i = 0; i < _optionControllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Radio<int>(
                  value: i,
                  // ignore: deprecated_member_use
                  groupValue: _correctIndex,
                  // ignore: deprecated_member_use
                  onChanged: (v) => setDialogState(() {
                    _correctIndex = v;
                    _correctAnswerUnreadable = false;
                  }),
                ),
                Expanded(
                  child: TextField(
                    controller: _optionControllers[i],
                    maxLength: 150,
                    decoration: InputDecoration(hintText: l10n.adminTrainingQuizOptionHint(i + 1), counterText: ''),
                  ),
                ),
                if (_optionControllers.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                    color: Accent.red500,
                    tooltip: l10n.adminTrainingQuizRemoveOptionTooltip,
                    onPressed: () => setDialogState(() {
                      _optionControllers.removeAt(i).dispose();
                      if (_correctIndex != null) {
                        if (_correctIndex == i) {
                          _correctIndex = null;
                        } else if (_correctIndex! > i) {
                          _correctIndex = _correctIndex! - 1;
                        }
                      }
                    }),
                  ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setDialogState(() => _optionControllers.add(TextEditingController())),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.adminTrainingQuizAddOptionTooltip),
          ),
        ),
      ];

  /// Returns the validated options, or null (after showing a SnackBar) if
  /// validation fails — same "fail loud, not silent" precedent as
  /// `admin_schemes_page.dart`'s blank-name check.
  List<String>? _validate(AppLocalizations l10n) {
    if (_question.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingQuizQuestionRequiredError)));
      return null;
    }
    final options = _optionControllers.map((c) => c.text.trim()).toList();
    if (options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingQuizMinOptionsError)));
      return null;
    }
    if (options.any((o) => o.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingQuizBlankOptionError)));
      return null;
    }
    if (_correctIndex == null || _correctIndex! >= options.length) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingQuizCorrectAnswerRequiredError)));
      return null;
    }
    return options;
  }

  Future<void> _addQuestion() async {
    final l10n = AppLocalizations.of(context)!;
    _question.clear();
    _resetOptions(['', '']);
    _correctIndex = null;
    _correctAnswerUnreadable = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.adminTrainingQuizAddDialogTitle),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: _formFields(setDialogState, l10n))),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionAdd)),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final options = _validate(l10n);
    if (options == null) return;
    setState(() => _busy = true);
    try {
      await _repo.createQuizQuestion(courseId: widget.courseId, question: _question.text.trim(), options: options, correctIndex: _correctIndex!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SupabaseService.isConfigured ? l10n.adminTrainingQuizAddedMessage : l10n.adminTrainingQuizDemoModeMessage)));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingQuizAddErrorMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editQuestion(QuizQuestion q) async {
    final l10n = AppLocalizations.of(context)!;
    _question.text = q.question;
    _resetOptions(q.options);
    _correctIndex = q.correctIndex;
    // See class doc comment: null here means migration 0060 isn't deployed
    // yet, not that this question genuinely has no correct answer (the DB
    // requires one, `quiz_questions_correct_index_in_range`).
    _correctAnswerUnreadable = q.correctIndex == null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.adminTrainingQuizEditDialogTitle),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: _formFields(setDialogState, l10n))),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionSave)),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final options = _validate(l10n);
    if (options == null) return;
    setState(() => _busy = true);
    try {
      await _repo.updateQuizQuestion(q.id, courseId: widget.courseId, question: _question.text.trim(), options: options, correctIndex: _correctIndex!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SupabaseService.isConfigured ? l10n.adminTrainingQuizUpdatedMessage : l10n.adminTrainingQuizDemoModeMessage)));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingQuizUpdateErrorMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteQuestion(QuizQuestion q) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adminTrainingQuizDeleteDialogTitle),
        content: Text(l10n.adminTrainingQuizDeleteDialogContent),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteQuizQuestion(q.id, courseId: widget.courseId);
      if (mounted) {
        _key.currentState?.reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SupabaseService.isConfigured ? l10n.adminTrainingQuizDeletedMessage : l10n.adminTrainingQuizDeleteDemoModeMessage)));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingQuizDeleteErrorMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = context.watch<AppState>().user.role;
    final isStaff = const {Role.crp, Role.clf, Role.admin}.contains(role);
    final title = widget.courseTitle != null ? l10n.adminTrainingQuizTitle(widget.courseTitle!) : l10n.adminTrainingCoursesTitle;

    return Scaffold(
      appBar: PageHeader(
        title: title,
        right: isStaff
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: !_busy ? Brand.c600 : Neutral.c300),
                onPressed: !_busy ? _addQuestion : null,
                tooltip: l10n.adminTrainingQuizAddQuestionTooltip,
              )
            : null,
      ),
      body: AppAsyncBuilder<List<QuizQuestion>>(
        key: _key,
        future: () => _repo.fetchQuizQuestionsForAdmin(widget.courseId),
        builder: (context, questions) {
          if (questions.isEmpty) {
            return AppEmptyState(icon: Icons.quiz_outlined, message: l10n.adminTrainingQuizEmptyState);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            itemBuilder: (context, i) {
              final q = questions[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(q.question, style: AppTheme.sans(13, weight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('${q.options.length} options', style: AppTheme.sans(11, color: Neutral.c500)),
                          ],
                        ),
                      ),
                      if (isStaff) ...[
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: !_busy ? Brand.c600 : Neutral.c300),
                          onPressed: !_busy ? () => _editQuestion(q) : null,
                          tooltip: l10n.adminTrainingQuizEditTooltip,
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: !_busy ? Accent.red500 : Neutral.c300),
                          onPressed: !_busy ? () => _deleteQuestion(q) : null,
                          tooltip: l10n.adminTrainingQuizDeleteTooltip,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
