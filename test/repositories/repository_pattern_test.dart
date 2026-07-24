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
  });

  // These exercise AnnouncementRepository.post's live-mode guard clauses
  // directly (the `shgId == null && !platformWide` check), which is safe to
  // do without a real Supabase project: the guard returns `false` before the
  // method ever reaches `_client`. This closes a real gap — until
  // `platformWide` existed, no code path in the app ever called `post()`
  // with `shgId: null`, so staff could never actually post a platform-wide
  // announcement despite RLS already permitting it (`is_staff()` bypasses
  // the `shg_id = current_shg_id()` check in
  // `announcements_insert_leader_or_staff`).
  group('AnnouncementRepository.post live-mode guard clauses (no live client needed)', () {
    test('a null shgId with platformWide:false (the leader-with-no-SHG defensive case) is denied before reaching the network', () async {
      SupabaseService.isConfigured = true;
      final repo = AnnouncementRepository();
      final posted = await repo.post(shgId: null, createdBy: 'leader-1', title: 'x', body: 'y', category: 'Circular');
      expect(posted, isFalse);
    });

    test('a null shgId with platformWide:true (the staff broadcast case) is NOT denied by the guard — it proceeds to the real insert', () async {
      SupabaseService.isConfigured = true;
      final repo = AnnouncementRepository();
      // No live Supabase project is configured in this test process, so the
      // guard clause passing means this reaches `_client.from(...).insert`,
      // which throws because `Supabase.instance` was never initialized —
      // confirming platformWide genuinely bypasses the null-shgId denial
      // rather than silently no-op'ing the same way the pre-fix code did.
      await expectLater(
        repo.post(shgId: null, createdBy: 'staff-1', title: 'x', body: 'y', category: 'Circular', platformWide: true),
        throwsA(anything),
      );
    });
  });

  test('AiAdvisorRepository defaults to MockAiAdvisorService (not the real Edge Function) when not configured', () async {
    final repo = AiAdvisorRepository();
    // The real EdgeFunctionAiAdvisorService would try to reach a live
    // Supabase client and throw/hang without one — completing quickly
    // with a plausible answer proves the demo-mode branch was chosen.
    final response = await repo.ask(memberId: null, advisorType: 'financial', query: 'How much should I save?');
    expect(response, isNotEmpty);
  });

  test('EdgeFunctionAiAdvisorService is a distinct real implementation of AiAdvisorService', () {
    // Compile-time/type check that the real Groq-backed service exists as
    // its own class alongside the mock, per the dual-mode pattern.
    expect(EdgeFunctionAiAdvisorService(), isA<AiAdvisorService>());
  });
}
