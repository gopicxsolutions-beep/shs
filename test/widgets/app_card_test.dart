import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/widgets/app_card.dart';

/// Regression coverage for the "ListTile background color or ink splashes
/// may be invisible" fix — AppCard was a plain Container with no Material
/// ancestor, so any interactive Material descendant (RadioListTile,
/// CheckboxListTile, Switch) placed inside one lost its ink-splash context.
void main() {
  testWidgets('AppCard provides a Material ancestor for its child', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AppCard(child: Text('content')),
      ),
    ));

    final cardMaterial = find.descendant(of: find.byType(AppCard), matching: find.byType(Material));
    expect(cardMaterial, findsOneWidget);
  });

  testWidgets('a RadioListTile inside AppCard renders without an ink-splash assertion', (tester) async {
    final errors = <FlutterErrorDetails>[];
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) => errors.add(details);
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AppCard(
          child: RadioGroup<int>(
            groupValue: 0,
            onChanged: (_) {},
            child: const Column(children: [
              RadioListTile<int>(value: 0, title: Text('Option A')),
              RadioListTile<int>(value: 1, title: Text('Option B')),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(errors, isEmpty, reason: 'RadioListTile inside AppCard should not trigger the missing-Material ink-splash assertion');
  });
}
