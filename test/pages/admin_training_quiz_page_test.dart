import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/admin/admin_training_quiz_page.dart';
import 'package:shg_saathi/repositories/training_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for the per-course quiz-question admin editor. A
/// course with zero quiz questions is reachable by members but its quiz
/// can't actually be taken (`submit_quiz_attempt` raises "no quiz questions
/// for this course") — this page is what makes an admin-created course
/// (see `admin_training_courses_page_test.dart`) usable end to end, not
/// just polish.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Future<void> boot(WidgetTester tester, {required String courseId, String role = 'admin'}) async {
    SharedPreferences.setMockInitialValues({
      'shg_session_started': true,
      'shg_authenticated': true,
      'shg_role': role,
    });
    final appState = AppState();
    await appState.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: AdminTrainingQuizPage(courseId: courseId, courseTitle: 'Test Course'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a freshly-created course with no questions shows the empty state, not a blank crash', (tester) async {
    final course = await TrainingRepository().createCourse(title: '__TEST__ Quiz Course A', topic: 'Testing', format: 'Video');
    await boot(tester, courseId: course.id);

    expect(find.text("No quiz questions yet — members can't take this course's quiz until you add some"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a question with options and a correct answer actually persists it (demo mode)', (tester) async {
    final course = await TrainingRepository().createCourse(title: '__TEST__ Quiz Course B', topic: 'Testing', format: 'Video');
    await boot(tester, courseId: course.id);

    await tester.tap(find.byTooltip('Add question'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Question'), '__TEST__ What is 2+2?');
    await tester.enterText(find.widgetWithText(TextField, 'Option 1'), '3');
    await tester.enterText(find.widgetWithText(TextField, 'Option 2'), '4');
    await tester.tap(find.byType(Radio<int>).at(1)); // select option 2 ("4") as correct
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Demo mode — question not saved (connect Supabase to persist)'), findsOneWidget);

    final questions = await TrainingRepository().fetchQuizQuestionsForAdmin(course.id);
    final created = questions.firstWhere((q) => q.question == '__TEST__ What is 2+2?');
    expect(created.options, ['3', '4']);
    expect(created.correctIndex, 1);
  });

  testWidgets('submitting without selecting a correct answer shows a validation message instead of silently saving', (tester) async {
    final course = await TrainingRepository().createCourse(title: '__TEST__ Quiz Course C', topic: 'Testing', format: 'Video');
    await boot(tester, courseId: course.id);

    await tester.tap(find.byTooltip('Add question'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Question'), '__TEST__ Unanswered question');
    await tester.enterText(find.widgetWithText(TextField, 'Option 1'), 'A');
    await tester.enterText(find.widgetWithText(TextField, 'Option 2'), 'B');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Select the correct answer.'), findsOneWidget);

    final questions = await TrainingRepository().fetchQuizQuestionsForAdmin(course.id);
    expect(questions.any((q) => q.question == '__TEST__ Unanswered question'), isFalse);
  });

  testWidgets('removing an option down to the 2-option minimum hides the remove button', (tester) async {
    final course = await TrainingRepository().createCourse(title: '__TEST__ Quiz Course D', topic: 'Testing', format: 'Video');
    await boot(tester, courseId: course.id);

    await tester.tap(find.byTooltip('Add question'));
    await tester.pumpAndSettle();

    // Starts at 2 options — the remove button must already be absent.
    expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNothing);

    await tester.tap(find.text('Add another option'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNWidgets(3));

    await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.remove_circle_outline_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing an existing pre-seeded mock question pre-fills its correct answer and persists a change', (tester) async {
    // Demo mode's mock course 'co1' already has real quiz content with a
    // known correctIndex (see lib/data/training.dart) — this exercises the
    // fetchQuizQuestionsForAdmin() -> fetchQuizQuestions() demo-mode path,
    // not just newly-admin-created questions.
    await boot(tester, courseId: 'co1');
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit question').first);
    await tester.pumpAndSettle();

    // Correct answer was pre-filled (not the "can't be shown" notice) —
    // demo mode's correctIndex is always populated.
    expect(find.text("This question's saved correct answer can't be shown here yet — pick it again before saving."), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Demo mode — question not saved (connect Supabase to persist)'), findsOneWidget);
  });

  testWidgets('a member account sees no Add/Edit/Delete controls', (tester) async {
    final course = await TrainingRepository().createCourse(title: '__TEST__ Quiz Course E', topic: 'Testing', format: 'Video');
    await boot(tester, courseId: course.id, role: 'member');

    expect(find.byTooltip('Add question'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
