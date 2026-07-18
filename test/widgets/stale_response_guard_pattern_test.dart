import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the request-generation guard pattern used by
/// `_ShgSearchSheetState._search()` in profile_setup_page.dart: without it,
/// a debounced search fired for an earlier, shorter query can resolve
/// *after* a newer, more specific query's response and clobber it, leaving
/// the UI showing results for a query the user is no longer looking at.
/// Since every real repository in this app resolves near-instantly in demo
/// mode, the out-of-order race can't be observed through a real page — this
/// exercises the exact same pattern shape in isolation with controllable,
/// independently-ordered delays instead.
class _GuardedSearch extends StatefulWidget {
  final Future<List<String>> Function(String query) search;
  const _GuardedSearch({required this.search});
  @override
  State<_GuardedSearch> createState() => _GuardedSearchState();
}

class _GuardedSearchState extends State<_GuardedSearch> {
  List<String> _results = [];
  int _generation = 0;

  Future<void> runSearch(String query) async {
    final generation = ++_generation;
    final results = await widget.search(query);
    if (mounted && generation == _generation) setState(() => _results = results);
  }

  @override
  Widget build(BuildContext context) {
    return Text(_results.join(','));
  }
}

void main() {
  testWidgets('a slower, earlier response cannot overwrite a faster, later one', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _GuardedSearch(
          search: (query) async {
            // The first ("a") query is deliberately the slowest, simulating
            // a stale in-flight request resolving after a newer one.
            await Future.delayed(Duration(milliseconds: query == 'a' ? 100 : 10));
            return [query];
          },
        ),
      ),
    ));

    final state = tester.state<_GuardedSearchState>(find.byType(_GuardedSearch));
    // Fire the slow, stale request first, then the fast, current one — same
    // ordering a user typing "a" then quickly refining to "ab" would produce.
    // Note: testWidgets runs on a fake clock that only advances via
    // tester.pump(duration) — awaiting the returned Futures directly would
    // deadlock forever, since the underlying Future.delayed never fires.
    unawaited(state.runSearch('a'));
    unawaited(state.runSearch('ab'));
    await tester.pump(const Duration(milliseconds: 10)); // lets 'ab' (10ms) resolve
    await tester.pump(const Duration(milliseconds: 100)); // lets 'a' (100ms) resolve too

    expect(find.text('ab'), findsOneWidget, reason: 'the latest request must win regardless of resolution order');
    expect(find.text('a'), findsNothing, reason: 'the stale response must not be applied after a newer request started');
  });

  testWidgets('a single in-flight request still applies its result normally', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _GuardedSearch(
          search: (query) async {
            await Future.delayed(const Duration(milliseconds: 20));
            return [query];
          },
        ),
      ),
    ));

    final state = tester.state<_GuardedSearchState>(find.byType(_GuardedSearch));
    unawaited(state.runSearch('shg'));
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('shg'), findsOneWidget);
  });
}
