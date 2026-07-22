import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shg_saathi/widgets/async_state.dart';

void main() {
  group('AppAsyncBuilder', () {
    testWidgets('shows a loading indicator while the future is pending', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppAsyncBuilder<String>(
          future: () => Future.delayed(const Duration(milliseconds: 50), () => 'done'),
          builder: (context, data) => Text(data),
        ),
      ));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('done'), findsNothing);

      // Let the pending timer finish before the test tears down the tree —
      // otherwise flutter_test flags it as a leaked pending timer.
      await tester.pumpAndSettle();
    });

    testWidgets('shows the builder content once the future resolves', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppAsyncBuilder<String>(
          future: () => Future.value('hello'),
          builder: (context, data) => Text(data),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows an error message and retry button on failure, and retry re-runs the future', (tester) async {
      var attempt = 0;
      await tester.pumpWidget(MaterialApp(
        home: AppAsyncBuilder<String>(
          future: () {
            attempt++;
            if (attempt == 1) return Future.error('boom');
            return Future.value('recovered');
          },
          builder: (context, data) => Text(data),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('recovered'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('recovered'), findsOneWidget);
      expect(attempt, 2);
    });

    testWidgets('shows an actionable connectivity message (not the generic one) for a dropped connection', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppAsyncBuilder<String>(
          future: () => Future<String>.error(http.ClientException('Failed to fetch')),
          builder: (context, data) => Text(data),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Check your internet connection and try again.'), findsOneWidget);
      expect(find.text('Something went wrong. Please try again.'), findsNothing);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('shows the same connectivity message for a client-side request timeout', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AppAsyncBuilder<String>(
          future: () => Future<String>.error(TimeoutException('timed out')),
          builder: (context, data) => Text(data),
        ),
      ));

      await tester.pumpAndSettle();

      expect(find.text('Check your internet connection and try again.'), findsOneWidget);
    });

    testWidgets('reload() re-invokes the future', (tester) async {
      var calls = 0;
      final key = GlobalKey<AppAsyncBuilderState<int>>();
      await tester.pumpWidget(MaterialApp(
        home: AppAsyncBuilder<int>(
          key: key,
          future: () => Future.value(++calls),
          builder: (context, data) => Text('$data'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);

      await key.currentState!.reload();
      await tester.pumpAndSettle();
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('AppEmptyState', () {
    testWidgets('renders the icon and message', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: AppEmptyState(icon: Icons.inbox_rounded, message: 'Nothing here yet'),
      ));

      expect(find.byIcon(Icons.inbox_rounded), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });
  });
}
