import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/pages/ai/ai_advisor_chat_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for a screen-reader gap: chat bubbles distinguished
/// "your message" from "their message" purely through alignment and color,
/// with zero text alternative — a screen reader reading the thread would
/// hear message text with no indication of who sent what.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  testWidgets('each chat bubble carries a Semantics label naming its sender', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: const MaterialApp(
        home: AiAdvisorChatPage(advisorType: 'financial', title: 'Financial Advisor', hint: 'Ask a question'),
      ),
    ));
    await tester.pumpAndSettle();

    final mySemantics = tester.getSemantics(find.ancestor(
      of: find.text('How much should I save every week?'),
      matching: find.byType(Semantics),
    ).first);
    expect(mySemantics.label, startsWith('You:'));

    final advisorSemantics = tester.getSemantics(find.ancestor(
      of: find.textContaining('Aim to save a fixed amount'),
      matching: find.byType(Semantics),
    ).first);
    expect(advisorSemantics.label, startsWith('Advisor:'));

    handle.dispose();
  });
}
