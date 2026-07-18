import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression coverage for the double-submit-guard pattern applied across
/// ~10 files this session (admin_schemes_page, announcements_home_page,
/// shg_documents_page, meeting_mom_page, admin_users_page, and others):
/// a `bool _busy` flag set before an async write, checked in the trigger
/// button's onPressed, reset in a finally block. Since every real repository
/// in this app resolves near-instantly in demo mode, the transient "busy"
/// window can't be observed through a real page — this exercises the exact
/// same pattern shape in isolation with a controllable delay instead.
class _GuardedButton extends StatefulWidget {
  final Future<void> Function() onSubmit;
  const _GuardedButton({required this.onSubmit});
  @override
  State<_GuardedButton> createState() => _GuardedButtonState();
}

class _GuardedButtonState extends State<_GuardedButton> {
  bool _busy = false;

  Future<void> _handle() async {
    setState(() => _busy = true);
    try {
      await widget.onSubmit();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _busy ? null : _handle,
      child: Text(_busy ? 'Working…' : 'Submit'),
    );
  }
}

void main() {
  testWidgets('the button disables while the async action is in flight, preventing a double-submit', (tester) async {
    var callCount = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: _GuardedButton(
          onSubmit: () async {
            callCount++;
            await Future.delayed(const Duration(milliseconds: 100));
          },
        ),
      ),
    ));

    await tester.tap(find.text('Submit'));
    await tester.pump(); // let setState(busy=true) apply, but not the delayed Future resolve
    expect(find.text('Working…'), findsOneWidget, reason: 'button should show the busy state immediately');

    // A second tap while busy must be a no-op — the button is disabled.
    await tester.tap(find.text('Working…'));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();

    expect(callCount, 1, reason: 'a rapid double-tap must only invoke the action once');
    expect(find.text('Submit'), findsOneWidget, reason: 'button re-enables once the action completes');
  });
}
