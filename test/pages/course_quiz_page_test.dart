import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/training/course_quiz_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/widgets/app_button.dart';

/// Regression coverage for the real per-course quiz content
/// (`quiz_questions` table / `lib/data/training.dart`'s `quizQuestions` map)
/// that replaced the single hardcoded, generic 3-question set previously
/// shared by every course regardless of its actual subject matter.
void main() {
  AppButton submitButton(WidgetTester tester) => tester.widget<AppButton>(find.byType(AppButton));

  setUp(() {
    SupabaseService.isConfigured = false;
  });

  /// The demo quiz's 5 questions + Submit button are taller than the
  /// default 800x600 test surface — Submit would be scrolled off-screen and
  /// thus "offstage" (excluded by the default skipOffstage:true finder
  /// behavior) even though it's genuinely present in the tree.
  Future<void> growSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('renders co1\'s own real quiz questions, not the old generic hardcoded set', (tester) async {
    await growSurface(tester);
    await tester.pumpWidget(MaterialApp(home: const CourseQuizPage(courseId: 'co1'), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ));
    await tester.pumpAndSettle();

    // co1 ("Basics of Household Budgeting") — genuine, on-topic content from
    // lib/data/training.dart's quizQuestions['co1'], distinct from co2's
    // EMI/interest content below.
    expect(find.textContaining('main purpose of a household budget'), findsOneWidget);
    expect(find.text('To plan and track income against expenses'), findsOneWidget);

    // The previous generic hardcoded question text must be gone.
    expect(find.textContaining('important to save regularly in an SHG'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('renders co2\'s own real quiz questions (different content than co1)', (tester) async {
    await growSurface(tester);
    await tester.pumpWidget(MaterialApp(home: const CourseQuizPage(courseId: 'co2'), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ));
    await tester.pumpAndSettle();

    // co2 ("Understanding Interest & EMI") — genuinely different, on-topic
    // content from co1's budgeting questions above.
    expect(find.textContaining('What does EMI stand for'), findsOneWidget);
    expect(find.text('Equated Monthly Installment'), findsOneWidget);
    expect(find.textContaining('main purpose of a household budget'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('selecting an answer in each question is tracked independently, enabling Submit once every question is answered', (tester) async {
    await growSurface(tester);
    await tester.pumpWidget(MaterialApp(home: const CourseQuizPage(courseId: 'co1'), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ));
    await tester.pumpAndSettle();

    expect(submitButton(tester).onPressed, isNull, reason: 'Submit should be disabled until all 5 questions are answered');

    // co1 has 5 questions (see lib/data/training.dart) — answer 4 and
    // confirm Submit is still disabled, then answer the last one.
    await tester.tap(find.text('To plan and track income against expenses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('House rent or loan EMI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('List and prioritize essential expenses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set aside savings before other spending'));
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNull, reason: 'Still 1 unanswered question');

    await tester.tap(find.text('To identify where money is going and cut unnecessary spending'));
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNotNull, reason: 'Submit should enable once all 5 questions are answered');

    expect(tester.takeException(), isNull);
  });

  testWidgets('a not-found courseId shows the empty state instead of a generic quiz', (tester) async {
    await growSurface(tester);
    await tester.pumpWidget(MaterialApp(home: const CourseQuizPage(courseId: 'does-not-exist'), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ));
    await tester.pumpAndSettle();

    expect(find.text('This course could not be found'), findsOneWidget);
    expect(find.byType(AppButton), findsNothing);
  });

  group('requiredScoreToPass (proportional ≥2/3 threshold for a variable question count)', () {
    test('3 questions (the old fixed quiz size) still requires 2 to pass', () {
      expect(requiredScoreToPass(3), 2);
    });
    test('5 questions (a typical seeded course) requires 4 to pass', () {
      expect(requiredScoreToPass(5), 4);
    });
    test('6 questions requires 4 to pass', () {
      expect(requiredScoreToPass(6), 4);
    });
  });

  testWidgets('scoring below the required threshold shows the retry message and does not navigate', (tester) async {
    await growSurface(tester);
    await tester.pumpWidget(MaterialApp(home: const CourseQuizPage(courseId: 'co1'), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ));
    await tester.pumpAndSettle();

    // Answer all 5 questions, deliberately getting only 3 right (below the
    // required 4-of-5 threshold): questions 1-3 correct, 4-5 wrong.
    await tester.tap(find.text('To plan and track income against expenses')); // Q1 correct
    await tester.pumpAndSettle();
    await tester.tap(find.text('House rent or loan EMI')); // Q2 correct
    await tester.pumpAndSettle();
    await tester.tap(find.text('List and prioritize essential expenses')); // Q3 correct
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spend first and save whatever is left over')); // Q4 wrong
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tracking expenses serves no real purpose')); // Q5 wrong
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AppButton, 'Submit Quiz'));
    await tester.pump();

    expect(find.text('You scored 3/5. Try again to pass.'), findsOneWidget);
    expect(find.byType(CourseQuizPage), findsOneWidget, reason: 'Failing the quiz should not navigate away');
  });
}
