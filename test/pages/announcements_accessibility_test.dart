import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/pages/announcements/announcements_home_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for a screen-reader gap: unread announcements were
/// only distinguished by a small colored dot with no text alternative, so
/// a screen reader user had no way to tell which announcements were unread.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  testWidgets('an unread announcement carries an "Unread" semantic label', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: const MaterialApp(home: AnnouncementsHomePage()),
    ));
    await tester.pumpAndSettle();

    // an1 is unread mock data — its row's title should carry an ancestor
    // Semantics label announcing "Unread" before the screen reader reaches
    // the title text.
    final unreadRowSemantics = tester.getSemantics(find.ancestor(
      of: find.text('DAY-NRLM interest subvention circular'),
      matching: find.byType(Semantics),
    ).first);
    expect(unreadRowSemantics.label, contains('Unread'));

    // an3 is read mock data — no such label should be present.
    final readRowSemantics = tester.getSemantics(find.ancestor(
      of: find.text('Digital Payments training on 12 Jul'),
      matching: find.byType(Semantics),
    ).first);
    expect(readRowSemantics.label, isNot(contains('Unread')));

    handle.dispose();
  });
}
