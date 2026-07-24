import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the exact pattern shape in
/// `announcement_detail_page.dart`'s `AppAsyncBuilder` future: fetch the
/// announcement, then best-effort try to mark it read, swallowing any
/// failure so a read-receipt write error never hides successfully-loaded
/// content. `AnnouncementRepository` has no injectable seam (unlike
/// `AnnouncementsHomePage`'s `notificationService`), so this isolates the
/// identical shape — fetch-then-best-effort-side-effect wrapped in
/// `try {} catch (_) {}` — in a controllable harness instead, the same
/// technique already used by `double_submit_guard_pattern_test.dart` for a
/// pattern that can't be forced to fail through the real page.
class _Content {
  final String title;
  const _Content(this.title);
}

Future<_Content?> _loadWithBestEffortSideEffect(Future<_Content?> Function() fetch, Future<void> Function() sideEffect) async {
  final content = await fetch();
  if (content != null) {
    try {
      await sideEffect();
    } catch (_) {
      // A side-effect failure must not hide successfully-loaded content.
    }
  }
  return content;
}

void main() {
  testWidgets('content still renders when the best-effort side effect throws', (tester) async {
    var sideEffectCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: FutureBuilder<_Content?>(
        future: _loadWithBestEffortSideEffect(
          () async => const _Content('A real announcement'),
          () async {
            sideEffectCalls++;
            throw Exception('read-receipt write failed');
          },
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox();
          return Text(snapshot.data!.title);
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(sideEffectCalls, 1, reason: 'the side effect must still have been attempted');
    expect(find.text('A real announcement'), findsOneWidget, reason: 'a thrown side effect must not prevent the fetched content from rendering');
    expect(tester.takeException(), isNull, reason: 'the swallowed exception must never surface to the widget tree');
  });

  testWidgets('a null fetch result never attempts the side effect at all', (tester) async {
    var sideEffectCalls = 0;
    await tester.pumpWidget(MaterialApp(
      home: FutureBuilder<_Content?>(
        future: _loadWithBestEffortSideEffect(
          () async => null,
          () async => sideEffectCalls++,
        ),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Text('not found');
          return Text(snapshot.data!.title);
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(sideEffectCalls, 0, reason: 'there is nothing to mark read when the fetch itself found nothing');
    expect(find.text('not found'), findsOneWidget);
  });
}
