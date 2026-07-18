import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/pages/training/course_quiz_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/widgets/app_button.dart';

/// Regression coverage for the deprecated-API migration this session:
/// course_quiz_page.dart's 3 independent RadioListTile groups were moved
/// off the deprecated per-widget groupValue/onChanged API onto Flutter's
/// RadioGroup ancestor widget. app_card_test.dart validated the pattern in
/// isolation; this confirms the real page's selection state and
/// answered-all-questions tracking still work correctly after the
/// migration — including that each question's RadioGroup is genuinely
/// independent (the incremental assertions below would fail as soon as
/// they mismatch if answering one question ever leaked into another's
/// group, since Submit only enables once all 3 are individually answered).
void main() {
  AppButton submitButton(WidgetTester tester) => tester.widget<AppButton>(find.byType(AppButton));

  testWidgets('selecting an answer in each question is tracked independently, enabling Submit once all 3 are answered', (tester) async {
    SupabaseService.isConfigured = true;
    addTearDown(() => SupabaseService.isConfigured = false);

    // The quiz's 3 questions + Submit button are taller than the default
    // 800x600 test surface — Submit would be scrolled off-screen and thus
    // "offstage" (excluded by the default skipOffstage:true finder
    // behavior) even though it's genuinely present in the tree.
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CourseQuizPage(courseId: 'co1')));
    await tester.pumpAndSettle();

    expect(submitButton(tester).onPressed, isNull, reason: 'Submit should be disabled until all 3 questions are answered');

    await tester.tap(find.text('It builds a financial cushion for the group'));
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNull, reason: 'Still 2 unanswered questions');

    await tester.tap(find.text('Understand the repayment terms and EMI'));
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNull, reason: 'Still 1 unanswered question');

    await tester.tap(find.text('The whole SHG, for transparency'));
    await tester.pumpAndSettle();
    expect(submitButton(tester).onPressed, isNotNull, reason: 'Submit should enable once all 3 questions are answered');

    expect(tester.takeException(), isNull);
  });
}
