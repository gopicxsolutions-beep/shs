import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/training/course_detail_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';
import 'package:shg_saathi/widgets/training_video_player.dart';

/// Regression coverage for the real in-app video player added to a course's
/// detail page (`Course.videoUrl`, migration 0115) — before this, no course
/// had any actual content viewer regardless of `format`.
///
/// Doesn't assert on the player ever reaching a playing state: under
/// `flutter test` there is no real video-decoding platform implementation
/// registered (same class of limitation already documented for the camera
/// QR scanner, voice mic, and file_picker elsewhere in this suite), so
/// `VideoPlayerController.initialize()` is expected to fail — the important
/// behavior to verify is that `TrainingVideoPlayer` catches that failure
/// itself (shown as its own error state) instead of crashing the page.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Widget harness(String courseId) => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: CourseDetailPage(courseId: courseId),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );

  testWidgets('a course with a video attached renders the video player, without crashing the page', (tester) async {
    // co1 ("Basics of Household Budgeting") carries a demo-mode sample
    // videoUrl — see lib/data/training.dart.
    await tester.pumpWidget(harness('co1'));
    await tester.pumpAndSettle();

    expect(find.byType(TrainingVideoPlayer), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a course with no video attached renders no video player', (tester) async {
    // co3 ("Starting a Micro Enterprise") is a PDF-format demo course with
    // no videoUrl.
    await tester.pumpWidget(harness('co3'));
    await tester.pumpAndSettle();

    expect(find.byType(TrainingVideoPlayer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
