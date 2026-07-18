import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/widgets/list_row.dart';

/// Regression coverage confirming AppListRow — used across the Members,
/// Documents, Loans, and other list screens — genuinely handles long
/// dynamic content (member names, addresses) without a RenderFlex
/// overflow, verified via code review earlier this session but never
/// executed against a real narrow layout until now.
void main() {
  testWidgets('a very long title and subtitle render without overflowing, even in a narrow row', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 200,
          child: AppListRow(
            title: 'A Genuinely Extremely Long Member Name That Would Never Fit On One Line',
            subtitle: 'An equally long village and district address that also would not fit',
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final titleWidget = tester.widget<Text>(find.textContaining('A Genuinely Extremely Long Member Name'));
    expect(titleWidget.maxLines, 1);
    expect(titleWidget.overflow, TextOverflow.ellipsis);
  });
}
