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

  // Real cross-turn conversation memory for the *current* chat session
  // (closes the gap docs/AI_MODULES.md §2.1 previously disclosed: no prior
  // turn was ever sent back to the model). One AiAdvisorRepository is
  // created fresh per open AiAdvisorChatPage
  // (`final _repo = AiAdvisorRepository()`), so without [seedSessionHistory]
  // below this list's lifetime would be scoped only to one open page
  // instance — a new page instance means a new repository instance means
  // empty history again. Capped to the most recent [_maxHistoryExchanges]
  // turns so a long-running chat can't make each outgoing request grow
  // unbounded (the Edge Function independently re-enforces its own bound
  // server-side too, regardless of what any caller sends). Never itself
  // written to a database — `ai_advisor_logs` (via `ask()`'s insert below)
  // remains the sole persisted record; this list is only ever built from it.
  static const _maxHistoryExchanges = 6;
  final List<AiAdvisorExchange> _sessionHistory = [];

  /// Seeds this session's LLM conversation memory from previously *persisted*
  /// exchanges (the same `ai_advisor_logs` rows `AiAdvisorChatPage` loads to
  /// render the reopened chat's bubbles) — bounded the same way a normal
  /// in-session accumulation is.
  ///
  /// Without this, reopening the chat page looked deceptively continuous —
  /// every prior question/answer still rendered as bubbles (§2.2 point 1) —
  /// but a fresh `AiAdvisorRepository` instance started with genuinely empty
  /// `_sessionHistory`, so the very next question sent to the LLM carried no
  /// context at all: a member who closed and reopened the app mid-
  /// conversation (or just navigated away and back) saw her own history on
  /// screen but got answers as if she'd never asked anything, which reads as
  /// "the assistant isn't remembering/storing what we talked about" — a real
  /// gap, not the intentional one docs/AI_MODULES.md §2.1/§2.3 previously
  /// described (that note was about the in-memory list never being written
  /// to a database at all, which remains true and correct; it did not mean
  /// the *display* history should also fail to inform the next LLM call).
  /// Call once, right after loading a page's persisted history, before any
  /// `ask()` call in that session.
  void seedSessionHistory(List<AiAdvisorExchange> exchanges) {
    _sessionHistory
      ..clear()
      ..addAll(
        exchanges.length > _maxHistoryExchanges
            ? exchanges.sublist(exchanges.length - _maxHistoryExchanges)
            : exchanges,
      );
  }

  Future<List<AiAdvisorLog>> fetchHistory({required String? memberId, required String advisorType}) async {
    if (!_live) {
      return mock.mockAdvisorLogs
          .where((l) => l.advisorType == advisorType)
          .map((l) => AiAdvisorLog(id: '${l.advisorType}-${l.query.hashCode}', memberId: 'me', advisorType: l.advisorType, query: l.query, response: l.response, createdAt: DateTime.now()))
          .toList();
    }
    if (memberId == null) return [];
    // Was the one remaining fully unbounded self-scoped history query in
    // this codebase — every sibling history fetch already caps at a few
    // hundred rows.
    final rows = await _client.from('ai_advisor_logs').select().eq('member_id', memberId).eq('advisor_type', advisorType).order('created_at').limit(300);
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
  Future<String> ask({required String? memberId, required String advisorType, required String query, String language = 'en'}) async {
    final response = await _service.ask(
      advisorType: advisorType,
      query: query,
      history: List.unmodifiable(_sessionHistory),
      language: language,
    );
    _sessionHistory.add(AiAdvisorExchange(query: query, response: response));
    if (_sessionHistory.length > _maxHistoryExchanges) {
      _sessionHistory.removeAt(0);
    }
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
