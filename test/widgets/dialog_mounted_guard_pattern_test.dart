import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the `context.mounted`-guard pattern applied to
/// the loan approval/payment dialogs' catch blocks this session
/// (loan_approval_page.dart's `_approve`, loan_detail_page.dart's
/// `_recordPayment`): showDialog's StatefulBuilder can be torn down
/// (Cancel, barrier dismiss) while an awaited repository call is still in
/// flight. The success path already guarded `Navigator.pop` with
/// `context.mounted`, but the catch block's `setState` did not — this
/// exercises the exact same dialog shape in isolation with a controllable
/// delay, since every real repository in this app resolves near-instantly
/// in demo mode and can't otherwise surface the race.
Future<bool?> _showGuardedDialog(BuildContext context, Future<void> Function() action) {
  String? error;
  return showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        content: Text(error ?? 'Working'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await action();
                if (context.mounted) Navigator.of(context).pop(true);
              } catch (_) {
                if (context.mounted) {
                  setState(() => error = 'Failed. Please try again.');
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('a catch block guarded by context.mounted does not throw when the dialog is dismissed before the awaited action fails', (tester) async {
    final completer = Completer<void>();
    late BuildContext launcherContext;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        launcherContext = context;
        return const Scaffold(body: SizedBox());
      }),
    ));

    unawaited(_showGuardedDialog(launcherContext, () => completer.future));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Submit'));
    await tester.pump(); // dialog is now awaiting `action()`

    // Dismiss the dialog (e.g. the user backs out) while the action is
    // still in flight.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Working'), findsNothing, reason: 'the dialog should be gone');

    // Now the in-flight action fails. Without the context.mounted guard,
    // the catch block's setState would throw "setState() called after
    // dispose()" — surfaced by the test framework as a failure.
    completer.completeError(Exception('late failure'));
    await tester.pump();
    await tester.pumpAndSettle();
  });
}
