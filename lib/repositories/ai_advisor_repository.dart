import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/ai_advisors.dart' as mock;
import '../models/ai_advisor.dart';
import '../services/ai_advisor_service.dart';
import '../services/supabase_service.dart';

/// Backed by `public.ai_advisor_logs` when Supabase is configured; falls
/// back to `lib/data/ai_advisors.dart` otherwise. The advisor call itself
/// goes through [AiAdvisorService] — [EdgeFunctionAiAdvisorService] (a real
/// Groq-backed LLM) when Supabase is configured, [MockAiAdvisorService] in
/// demo mode — this repository only ever records the *result* of that call.
class AiAdvisorRepository {
  AiAdvisorRepository({AiAdvisorService? service}) : _service = service ?? (SupabaseService.isConfigured ? EdgeFunctionAiAdvisorService() : MockAiAdvisorService());

  final AiAdvisorService _service;
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  Future<List<AiAdvisorLog>> fetchHistory({required String? memberId, required String advisorType}) async {
    if (!_live) {
      return mock.mockAdvisorLogs
          .where((l) => l.advisorType == advisorType)
          .map((l) => AiAdvisorLog(id: '${l.advisorType}-${l.query.hashCode}', memberId: 'me', advisorType: l.advisorType, query: l.query, response: l.response, createdAt: DateTime.now()))
          .toList();
    }
    if (memberId == null) return [];
    final rows = await _client.from('ai_advisor_logs').select().eq('member_id', memberId).eq('advisor_type', advisorType).order('created_at');
    return (rows as List).map((r) => AiAdvisorLog.fromMap(r as Map<String, dynamic>)).toList();
  }

  /// Runs the (mock) advisor call, then records the interaction. Returns
  /// the response text so the UI can show it immediately.
  ///
  /// The log insert is best-effort: it must not turn a real, already-
  /// obtained LLM answer into a user-facing failure. Before this fix, a
  /// transient failure on the `ai_advisor_logs` insert (network blip, RLS
  /// mismatch, etc.) propagated out of `ask()` uncaught, so
  /// `AiAdvisorChatPage._ask()`'s catch block discarded the genuine answer
  /// entirely and showed "Sorry, something went wrong" instead — the
  /// member's question was actually answered, but they'd never see it.
  /// Mirrors `announcement_detail_page.dart`'s established "read-receipt
  /// failure must not hide successfully-loaded content" pattern.
  Future<String> ask({required String? memberId, required String advisorType, required String query}) async {
    final response = await _service.ask(advisorType: advisorType, query: query);
    if (_live && memberId != null) {
      try {
        await _client.from('ai_advisor_logs').insert({
          'member_id': memberId,
          'advisor_type': advisorType,
          'query': query,
          'response': response,
        });
      } catch (_) {
        // Logging failure must not hide an already-successful answer.
      }
    }
    return response;
  }
}
