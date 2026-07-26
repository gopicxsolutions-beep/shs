import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/admin/admin_training_courses_page.dart';
import 'package:shg_saathi/repositories/training_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for the previously-missing "Manage Training Courses"
/// admin page: the live `training_courses` table was confirmed empty with
/// no UI path to populate it despite RLS already permitting crp/clf/admin
/// writes (`training_courses_write_staff`) — see the page's own class doc
/// comment. Mirrors `admin_schemes_page_test.dart`'s pattern.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Future<void> boot(WidgetTester tester, {String role = 'admin'}) async {
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
          home: const AdminTrainingCoursesPage(),
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

  testWidgets('a crp account (not just admin) sees Add/Edit/Delete controls — RLS grants crp writes here too', (tester) async {
    await boot(tester, role: 'crp');
    expect(find.byTooltip('Add course'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a member account sees no Add/Edit/Delete controls', (tester) async {
    await boot(tester, role: 'member');
    expect(find.byTooltip('Add course'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adding a course actually persists it (demo mode)', (tester) async {
    await boot(tester);

    await tester.tap(find.byTooltip('Add course'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Course title'), '__TEST__ Widget Course');
    await tester.enterText(find.widgetWithText(TextField, 'Topic'), 'Testing');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Demo mode — course not saved (connect Supabase to persist)'), findsOneWidget);

    final courses = await TrainingRepository().fetchCourses();
    final created = courses.firstWhere((c) => c.title == '__TEST__ Widget Course');
    expect(created.topic, 'Testing');
    expect(created.format, 'Video');
  });

  testWidgets('a blank course title shows a validation message instead of silently saving', (tester) async {
    await boot(tester);

    await tester.tap(find.byTooltip('Add course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Course title is required.'), findsOneWidget);

    final courses = await TrainingRepository().fetchCourses();
    // The pre-existing mock catalog has 6 courses — none of them blank.
    expect(courses.any((c) => c.title.trim().isEmpty), isFalse);
  });

  testWidgets('editing a course persists the change', (tester) async {
    await TrainingRepository().createCourse(title: '__TEST__ Editable Course', topic: 'Original Topic', format: 'PDF');
    await boot(tester);

    await tester.scrollUntilVisible(find.byTooltip('Edit __TEST__ Editable Course'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit __TEST__ Editable Course'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Topic'), 'Updated Topic');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final courses = await TrainingRepository().fetchCourses();
    expect(courses.firstWhere((c) => c.title == '__TEST__ Editable Course').topic, 'Updated Topic');
  });

  testWidgets('deleting a course removes it', (tester) async {
    await TrainingRepository().createCourse(title: '__TEST__ Deletable Course', topic: 'Testing', format: 'PDF');
    await boot(tester);

    await tester.scrollUntilVisible(find.byTooltip('Delete __TEST__ Deletable Course'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete __TEST__ Deletable Course'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final courses = await TrainingRepository().fetchCourses();
    expect(courses.any((c) => c.title == '__TEST__ Deletable Course'), isFalse);
  });
}
