import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/models/ai_advisor.dart';
import 'package:shg_saathi/pages/ai/ai_advisor_chat_page.dart';
import 'package:shg_saathi/repositories/ai_advisor_repository.dart';
import 'package:shg_saathi/services/ai_advisor_service.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for the bug reported live: the AI Advisor chat
/// re-rendered every prior question/answer as bubbles on reopen (loaded
/// from persisted history — see AiAdvisorRepository.fetchHistory), but a
/// fresh AiAdvisorRepository instance's in-memory session history — the
/// list actually forwarded to the LLM for conversation context — started
/// genuinely empty every time, so the model itself had no memory of a
/// conversation the member could see right there on screen. Fixed by
/// AiAdvisorChatPage._loadHistory calling
/// AiAdvisorRepository.seedSessionHistory() with the same rows it uses to
/// build the visible transcript.
///
/// Exercises the real page + real repository wiring (not just the
/// repository in isolation, already covered by
/// test/repositories/ai_advisor_repository_test.dart) using demo mode's
/// canned `mockAdvisorLogs` as the "persisted history" fetchHistory
/// returns, and a fake [AiAdvisorService] (like
/// test/pages/ai_advisor_chat_error_messages_test.dart's) to capture
/// exactly what history a subsequent ask() call carries.
class _RecordingAiAdvisorService implements AiAdvisorService {
  final List<List<AiAdvisorExchange>> capturedHistories = [];

  @override
  Future<String> ask({
    required String advisorType,
    required String query,
    List<AiAdvisorExchange> history = const [],
    String language = 'en',
  }) async {
    capturedHistories.add(List.of(history));
    return 'a fresh answer';
  }
}

void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  testWidgets('reopening the chat page seeds the model with the persisted history it just displayed, not a blank slate', (tester) async {
    final fakeService = _RecordingAiAdvisorService();
    final repo = AiAdvisorRepository(service: fakeService);

    await tester.pumpWidget(ChangeNotifierProvider<AppState>(
      create: (_) => AppState(),
      child: MaterialApp(
        home: AiAdvisorChatPage(
          advisorType: 'financial',
          title: 'Financial Advisor',
          hint: 'Ask a question',
          repository: repo,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // The mock financial-advisor history bubble must actually be visible —
    // otherwise this test would trivially pass with no real history loaded.
    expect(find.text('How much should I save every week?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'a follow-up question');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pumpAndSettle();

    expect(fakeService.capturedHistories, hasLength(1));
    final sentHistory = fakeService.capturedHistories.single;
    expect(sentHistory, isNotEmpty, reason: 'the follow-up must carry the already-displayed prior exchange as real context, not start blank');
    expect(sentHistory.single.query, 'How much should I save every week?');
  });
}
