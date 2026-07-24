import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/ai_advisor.dart';
import 'package:shg_saathi/repositories/ai_advisor_repository.dart';
import 'package:shg_saathi/services/ai_advisor_service.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for real cross-turn conversation memory (closes the
/// gap docs/AI_MODULES.md §2.1 previously disclosed: no prior turn was ever
/// sent back to the model, even though the chat UI visually shows a running
/// list of Q&A pairs). [AiAdvisorRepository] now keeps the current chat
/// session's prior turns in memory and forwards a bounded, most-recent
/// slice of them to [AiAdvisorService.ask] alongside every new query.
///
/// Uses the repository's existing constructor-injection seam
/// (`AiAdvisorRepository({AiAdvisorService? service})`, already exercised
/// by test/repositories/repository_pattern_test.dart) with a fake
/// [AiAdvisorService] that records exactly the `history` it was called
/// with, so these tests exercise the real accumulation logic rather than
/// manually threading history through.
class _FakeAiAdvisorService implements AiAdvisorService {
  final List<List<AiAdvisorExchange>> capturedHistories = [];
  int _calls = 0;

  @override
  Future<String> ask({
    required String advisorType,
    required String query,
    List<AiAdvisorExchange> history = const [],
  }) async {
    capturedHistories.add(List.of(history));
    _calls++;
    return 'answer-$_calls';
  }
}

void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  test('the first ask() call in a session sends no history', () async {
    final fake = _FakeAiAdvisorService();
    final repo = AiAdvisorRepository(service: fake);

    await repo.ask(memberId: null, advisorType: 'financial', query: 'How much should I save?');

    expect(fake.capturedHistories, hasLength(1));
    expect(fake.capturedHistories.single, isEmpty);
  });

  test('a second ask() call in the same session includes the first exchange', () async {
    final fake = _FakeAiAdvisorService();
    final repo = AiAdvisorRepository(service: fake);

    await repo.ask(memberId: null, advisorType: 'financial', query: 'How much should I save?');
    await repo.ask(memberId: null, advisorType: 'financial', query: 'And what about loans?');

    expect(fake.capturedHistories, hasLength(2));
    expect(fake.capturedHistories[0], isEmpty, reason: 'first request must carry no history');
    expect(fake.capturedHistories[1], hasLength(1), reason: 'second request must carry exactly the first exchange');
    expect(fake.capturedHistories[1].single.query, 'How much should I save?');
    expect(fake.capturedHistories[1].single.response, 'answer-1');
  });

  test('a third ask() call includes both prior exchanges, in order', () async {
    final fake = _FakeAiAdvisorService();
    final repo = AiAdvisorRepository(service: fake);

    await repo.ask(memberId: null, advisorType: 'scheme', query: 'q1');
    await repo.ask(memberId: null, advisorType: 'scheme', query: 'q2');
    await repo.ask(memberId: null, advisorType: 'scheme', query: 'q3');

    final thirdRequestHistory = fake.capturedHistories[2];
    expect(thirdRequestHistory, hasLength(2));
    expect(thirdRequestHistory[0].query, 'q1');
    expect(thirdRequestHistory[0].response, 'answer-1');
    expect(thirdRequestHistory[1].query, 'q2');
    expect(thirdRequestHistory[1].response, 'answer-2');
  });

  test('session history stays bounded and does not grow unbounded across many turns', () async {
    final fake = _FakeAiAdvisorService();
    final repo = AiAdvisorRepository(service: fake);

    for (var i = 1; i <= 10; i++) {
      await repo.ask(memberId: null, advisorType: 'market', query: 'question $i');
    }

    final lastRequestHistory = fake.capturedHistories.last;
    expect(lastRequestHistory.length, lessThanOrEqualTo(6));
    // Only the most recent turns should survive — the 10th call's history
    // must end with the 9th question, not carry the entire ten-turn session.
    expect(lastRequestHistory.last.query, 'question 9');
    expect(lastRequestHistory.any((e) => e.query == 'question 1'), isFalse, reason: 'the oldest turns must have been dropped, not accumulated forever');
  });

  test('a new AiAdvisorRepository instance (a fresh page open) starts with no memory', () async {
    final fakeA = _FakeAiAdvisorService();
    final repoA = AiAdvisorRepository(service: fakeA);
    await repoA.ask(memberId: null, advisorType: 'financial', query: 'q1 in session A');

    final fakeB = _FakeAiAdvisorService();
    final repoB = AiAdvisorRepository(service: fakeB);
    await repoB.ask(memberId: null, advisorType: 'financial', query: 'q1 in session B');

    expect(fakeB.capturedHistories.single, isEmpty, reason: 'a fresh repository instance must not see another session\'s history');
  });

  test('demo-mode MockAiAdvisorService also accepts and ignores the history parameter without throwing', () async {
    // Not live-backed, but AiAdvisorRepository always threads history
    // through regardless of _live, so the mock path must accept the same
    // signature without crashing in demo mode.
    final repo = AiAdvisorRepository();
    final first = await repo.ask(memberId: null, advisorType: 'financial', query: 'How much should I save every week?');
    final second = await repo.ask(memberId: null, advisorType: 'financial', query: 'What about loans?');
    expect(first, isNotEmpty);
    expect(second, isNotEmpty);
  });
}
