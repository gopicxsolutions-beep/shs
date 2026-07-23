import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/models/ai_advisor.dart';
import 'package:shg_saathi/pages/ai/ai_advisor_chat_page.dart';
import 'package:shg_saathi/repositories/ai_advisor_repository.dart';
import 'package:shg_saathi/services/ai_advisor_service.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for the documented gap in docs/AI_MODULES.md §2.2 /
/// §6: the chat page used to flatten every server-side ai-advisor-proxy
/// failure into one of just two generic messages via `isNetworkError`
/// branching, discarding the Edge Function's actual, already member-safe
/// rejection reason — most importantly the content-moderation pre-filter's
/// specific, supportive self-harm rejection text (see
/// `supabase/functions/ai-advisor-proxy/moderation.ts`'s `SELF_HARM_REASON`).
///
/// A [_ThrowingAiAdvisorService] stands in for a live Edge Function call
/// that failed in a specific, distinguishable way, wired in through
/// [AiAdvisorRepository]'s existing `service` injection seam and
/// [AiAdvisorChatPage]'s `repository` injection seam — no live Supabase
/// project needed.
class _ThrowingAiAdvisorService implements AiAdvisorService {
  final Object Function() makeError;
  const _ThrowingAiAdvisorService(this.makeError);

  @override
  Future<String> ask({
    required String advisorType,
    required String query,
    List<AiAdvisorExchange> history = const [],
  }) async {
    throw makeError();
  }
}

const _selfHarmReason =
    "This looks like it may be about self-harm. This assistant can't help with that — please reach out to someone you trust, your SHG leader, or a local helpline right away.";
const _rateLimitReason = 'Too many requests. Please wait a minute before asking again.';
const _upstreamUnavailableMessage =
    'The advisor service is temporarily unavailable right now. Please try again in a moment.';
const _genericFallback = 'Something went wrong. Please try again.';
const _networkFallback = 'Check your internet connection and try again.';

Future<void> _askAndSettle(WidgetTester tester, Object Function() makeError) async {
  final repo = AiAdvisorRepository(service: _ThrowingAiAdvisorService(makeError));
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

  await tester.enterText(find.byType(TextField), 'test question');
  await tester.tap(find.byIcon(Icons.send_rounded));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  testWidgets('a 400 moderation pre-filter rejection shows the exact supportive reason verbatim', (tester) async {
    await _askAndSettle(tester, () => const AiAdvisorRequestException(400, _selfHarmReason));

    expect(find.text(_selfHarmReason), findsOneWidget);
    expect(find.text(_genericFallback), findsNothing);
    expect(find.text(_networkFallback), findsNothing);
  });

  testWidgets('a 400 basic-validation rejection also shows its reason verbatim', (tester) async {
    const reason = 'query is too long (max 2000 characters)';
    await _askAndSettle(tester, () => const AiAdvisorRequestException(400, reason));

    expect(find.text(reason), findsOneWidget);
  });

  testWidgets('a 429 rate-limit rejection shows the exact rate-limit reason verbatim', (tester) async {
    await _askAndSettle(tester, () => const AiAdvisorRequestException(429, _rateLimitReason));

    expect(find.text(_rateLimitReason), findsOneWidget);
    expect(find.text(_genericFallback), findsNothing);
  });

  testWidgets('a 401 unidentified-caller failure shows the shared upstream-unavailable message, not the raw reason', (tester) async {
    await _askAndSettle(tester, () => const AiAdvisorRequestException(401, 'Could not identify the authenticated caller.'));

    expect(find.text(_upstreamUnavailableMessage), findsOneWidget);
    expect(find.text('Could not identify the authenticated caller.'), findsNothing);
  });

  testWidgets('a 500 internal-error failure shows the shared upstream-unavailable message, not the raw reason', (tester) async {
    await _askAndSettle(tester, () => const AiAdvisorRequestException(500, 'Internal error'));

    expect(find.text(_upstreamUnavailableMessage), findsOneWidget);
    expect(find.text('Internal error'), findsNothing);
  });

  testWidgets('a 502 upstream-provider failure shows the shared upstream-unavailable message', (tester) async {
    await _askAndSettle(tester, () => const AiAdvisorRequestException(502, 'The advisor service is temporarily unavailable. Please try again.'));

    expect(find.text(_upstreamUnavailableMessage), findsOneWidget);
  });

  testWidgets('a genuine dropped-connection failure still shows the generic network message', (tester) async {
    await _askAndSettle(tester, () => TimeoutException('timed out'));

    expect(find.text(_networkFallback), findsOneWidget);
  });

  testWidgets('an unclassifiable error still falls back to the generic message', (tester) async {
    await _askAndSettle(tester, () => Exception('some unexpected shape'));

    expect(find.text(_genericFallback), findsOneWidget);
  });
}
