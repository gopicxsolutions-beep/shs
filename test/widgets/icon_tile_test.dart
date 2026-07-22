import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/widgets/icon_tile.dart';

/// The small count badge (e.g. "3" on a leader's "Approvals" tile) is a
/// separate Text node overlaid on the icon — visually obvious, but a screen
/// reader announces the bare number with nothing tying it to what it counts.
/// Regression coverage for the Semantics/ExcludeSemantics fix added this
/// session (same pattern as TrendChart's canvas summary).
void main() {
  testWidgets('a tile with no badge exposes just its label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: IconTile(onTap: () {}, icon: Icons.groups_rounded, label: 'Members')),
    ));

    final semantics = tester.getSemantics(find.byType(IconTile));
    expect(semantics.label, 'Members');
  });

  testWidgets('a badged tile ties the count to its label instead of announcing a bare number', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IconTile(onTap: () {}, icon: Icons.fact_check_rounded, label: 'Approvals', badge: '3', badgeSemanticLabel: 'Approvals, 3 pending'),
      ),
    ));

    expect(tester.getSemantics(find.byType(IconTile)), matchesSemantics(label: 'Approvals, 3 pending', isButton: true, hasTapAction: true));
  });

  testWidgets('a badged tile without an explicit semantic label still ties the number to the label', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: IconTile(onTap: () {}, icon: Icons.description_rounded, label: 'Schemes', badge: '2')),
    ));

    final semantics = tester.getSemantics(find.byType(IconTile));
    expect(semantics.label, 'Schemes, 2');
  });
}
