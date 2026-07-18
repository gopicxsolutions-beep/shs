import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/repositories/ai_advisor_repository.dart';
import 'package:shg_saathi/repositories/announcement_repository.dart';
import 'package:shg_saathi/repositories/savings_repository.dart';
import 'package:shg_saathi/services/ai_advisor_service.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Exercises the dual-mode repository pattern used across every module:
/// when [SupabaseService.isConfigured] is false (the default, and the only
/// state reachable in a widget test without a live Supabase project), every
/// repository must fall back to its `lib/data/*.dart` mock data instead of
/// touching the Supabase client.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  group('demo-mode fallback', () {
    test('SavingsRepository.fetchForMember returns mock entries without a live client', () async {
      final repo = SavingsRepository();
      final entries = await repo.fetchForMember(null);
      expect(entries, isNotEmpty);
    });

    test('SavingsRepository.fetchForShg returns mock entries without a live client', () async {
      final repo = SavingsRepository();
      final entries = await repo.fetchForShg(null);
      expect(entries, isNotEmpty);
    });

    test('AnnouncementRepository.fetchForShg returns mock announcements without a live client', () async {
      final repo = AnnouncementRepository();
      final announcements = await repo.fetchForShg(null, null);
      expect(announcements, isNotEmpty);
      expect(announcements.first.title, isNotEmpty);
    });

    test('AnnouncementRepository writes are a no-op without a live client (do not throw)', () async {
      final repo = AnnouncementRepository();
      await repo.markRead('an1', null);
      await repo.post(shgId: null, createdBy: null, title: 'x', body: 'y', category: 'Circular');
      // No exception means the demo-mode guard clauses did their job.
    });

    test('AiAdvisorRepository defaults to MockAiAdvisorService (not the real Edge Function) when not configured', () async {
      final repo = AiAdvisorRepository();
      // The real EdgeFunctionAiAdvisorService would try to reach a live
      // Supabase client and throw/hang without one — completing quickly
      // with a plausible answer proves the demo-mode branch was chosen.
      final response = await repo.ask(memberId: null, advisorType: 'financial', query: 'How much should I save?');
      expect(response, isNotEmpty);
    });
  });

  test('EdgeFunctionAiAdvisorService is a distinct real implementation of AiAdvisorService', () {
    // Compile-time/type check that the real Groq-backed service exists as
    // its own class alongside the mock, per the dual-mode pattern.
    expect(EdgeFunctionAiAdvisorService(), isA<AiAdvisorService>());
  });
}
