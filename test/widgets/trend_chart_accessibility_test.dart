import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/trend.dart';
import 'package:shg_saathi/widgets/trend_chart.dart';

/// TrendChart wraps an fl_chart LineChart, which paints its data on a
/// canvas that a screen reader cannot read — without a Semantics label a
/// blind user gets no information about the trend at all. Regression
/// coverage for the Semantics/ExcludeSemantics wrapper added this session.
void main() {
  testWidgets('exposes a textual semantics summary of the plotted points instead of an inaccessible canvas', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: TrendChart(
          points: const [
            MonthlyPoint('Jan', 100),
            MonthlyPoint('Feb', 150),
          ],
          suffix: '%',
        ),
      ),
    ));

    final semantics = tester.getSemantics(find.byType(TrendChart));
    expect(semantics.label, contains('Jan 100%'));
    expect(semantics.label, contains('Feb 150%'));
    expect(semantics.label, contains('up'));
  });

  testWidgets('an empty chart still exposes a semantics label instead of silence', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: TrendChart(points: [])),
    ));

    final semantics = tester.getSemantics(find.byType(TrendChart));
    expect(semantics.label, 'Trend chart: no data');
  });
}
