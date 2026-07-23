import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ai_advisor.dart';
import 'supabase_service.dart';

/// Abstraction over a real LLM-backed advisor API.
/// See docs/DEVELOPMENT_PROGRESS.md's "External API abstraction plan".
abstract class AiAdvisorService {
  /// [advisorType] is one of 'financial' | 'scheme' | 'market', matching
  /// the `ai_advisor_logs.advisor_type` check constraint.
  ///
  /// [history] is a bounded, most-recent slice of the current chat
  /// session's prior turns (see [AiAdvisorExchange] and
  /// `AiAdvisorRepository`) — real cross-turn memory, sent to the provider
  /// as actual prior user/assistant messages rather than folded into the
  /// query text.
  Future<String> ask({
    required String advisorType,
    required String query,
    List<AiAdvisorExchange> history = const [],
  });
}

/// Carries the ai-advisor-proxy Edge Function's actual, distinguishable
/// failure category through to the UI, instead of every server-side
/// rejection collapsing into one opaque [Exception] string that the chat
/// page can't tell apart from a dropped connection.
///
/// [statusCode] mirrors the function's real HTTP response (see
/// `supabase/functions/ai-advisor-proxy/index.ts`'s `HttpError`):
/// - 400 — the content-moderation pre-filter or basic request validation
///   rejected the query. [reason] is already written to be shown to the
///   member as-is (see `moderation.ts`'s `*_REASON` constants — most
///   importantly the supportive, safety-oriented self-harm wording — and
///   index.ts's own validation messages).
/// - 429 — the per-member rate limit was hit. [reason] is again a
///   member-safe, specific instruction ("wait a minute").
/// - 401/500/502 — an upstream/auth/provider failure that is the
///   service's fault, not the member's; some of those raw reasons (e.g.
///   "Internal error") are not written for end users, so callers should
///   not show [reason] verbatim for this bucket.
class AiAdvisorRequestException implements Exception {
  final int statusCode;
  final String reason;
  const AiAdvisorRequestException(this.statusCode, this.reason);

  @override
  String toString() => 'AiAdvisorRequestException($statusCode): $reason';
}

/// Maps a [FunctionException] thrown by `SupabaseClient.functions.invoke`
/// (for any non-2xx `ai-advisor-proxy` response) into the distinguishable
/// [AiAdvisorRequestException] above. A pure function, kept separate from
/// [EdgeFunctionAiAdvisorService.ask] so the actual status+reason
/// translation is unit-testable without a live Supabase Functions client
/// (see test/services/ai_advisor_service_test.dart).
AiAdvisorRequestException mapFunctionExceptionToAdvisorException(FunctionException e) {
  final details = e.details;
  final reason = details is Map && details['error'] is String
      ? details['error'] as String
      : (e.reasonPhrase ?? 'AI advisor request failed');
  return AiAdvisorRequestException(e.status, reason);
}

/// Calls the deployed `ai-advisor-proxy` Edge Function, which proxies to a
/// real LLM (Groq's `llama-3.3-70b-versatile`) — the provider key stays
/// server-side. Used whenever Supabase is configured; falls back to
/// [MockAiAdvisorService] only in demo mode (see `AiAdvisorRepository`).
class EdgeFunctionAiAdvisorService implements AiAdvisorService {
  SupabaseClient get _client => SupabaseService.instance.client;

  @override
  Future<String> ask({
    required String advisorType,
    required String query,
    List<AiAdvisorExchange> history = const [],
  }) async {
    Map<String, dynamic>? data;
    try {
      final res = await _client.functions.invoke('ai-advisor-proxy', body: {
        'advisor_type': advisorType,
        'query': query,
        if (history.isNotEmpty) 'history': history.map((h) => h.toJson()).toList(),
      });
      data = res.data as Map<String, dynamic>?;
    } on FunctionException catch (e) {
      // Any non-2xx response (400 validation/moderation rejection, 401
      // unidentified caller, 429 rate-limited, 500/502 upstream failure —
      // see index.ts's HttpError) is surfaced by the functions client as
      // `FunctionException.details` (the decoded JSON error body), not as
      // `res.data` above — the old code here never actually reached the
      // `data['ok'] != true` branch below for any real server-side
      // rejection, including the moderation pre-filter's specific reason.
      // Thread the real status + reason through as a distinguishable
      // exception instead of one generic string.
      throw mapFunctionExceptionToAdvisorException(e);
    }
    if (data == null || data['ok'] != true) {
      throw AiAdvisorRequestException(500, (data?['error'] as String?) ?? 'unknown error');
    }
    return data['response'] as String;
  }
}

/// Keyword-matches the query against a small canned response set per
/// advisor type, so the ask → log → display flow is fully real and
/// testable without a live LLM key. Falls back to a generic acknowledgement
/// when nothing matches.
class MockAiAdvisorService implements AiAdvisorService {
  static const _responses = <String, List<(List<String>, String)>>{
    'financial': [
      (
        ['save', 'saving', 'savings'],
        'Aim to save a fixed amount every meeting rather than a variable one — even ₹100/week builds a steady corpus your group can lend against. Check your Savings ledger to see your current streak.',
      ),
      (
        ['loan', 'emi', 'interest'],
        'Before taking a new loan, check your existing EMI load against your income — a common rule of thumb is to keep total EMIs under 40% of household income. Your Loans tab shows all outstanding balances.',
      ),
      (
        ['budget', 'expense', 'spend'],
        'Track your livelihood income and expenses separately from household spending — the Livelihoods tab helps you see if an activity is actually profitable after costs.',
      ),
    ],
    'scheme': [
      (
        ['mudra', 'business loan'],
        'MUDRA loans are collateral-free up to ₹10 lakh for small businesses. Check the Schemes tab and use the Eligibility Checker to see if your SHG grade and activity type qualify.',
      ),
      (
        ['subsidy', 'interest subvention'],
        'DAY-NRLM interest subvention can bring your effective loan interest down significantly for A-grade SHGs with good repayment history — see the latest circular under Announcements.',
      ),
      (
        ['pension', 'insurance'],
        'Government social security schemes (pension, insurance) are usually applied for through your SHG leader or CRP — check the Schemes catalog for ones currently open in your district.',
      ),
    ],
    'market': [
      (
        ['sell', 'price', 'market'],
        'Compare prices across at least 2-3 buyers before committing — the Marketplace tab lets you see what similar products from other SHGs are listed at.',
      ),
      (
        ['demand', 'season'],
        'Seasonal products (festival goods, produce) sell best when listed 2-3 weeks ahead of the season — plan your Marketplace listing timing around local festival calendars.',
      ),
      (
        ['packaging', 'quality'],
        'Simple, consistent packaging with your SHG name builds buyer trust over repeat orders — even a basic printed label makes a noticeable difference.',
      ),
    ],
  };

  static const _fallback = <String, String>{
    'financial': 'That is a good financial question — for now, check your Savings, Loans, and Livelihoods tabs for the specific numbers, and ask your SHG leader or CRP for guidance tailored to your group.',
    'scheme': 'For scheme-specific queries, browse the Schemes tab and use the Eligibility Checker, or ask your CRP — new schemes are added there as they become available.',
    'market': 'For market-specific queries, browse similar listings in the Marketplace tab to get a sense of pricing and demand in your area.',
  };

  @override
  Future<String> ask({
    required String advisorType,
    required String query,
    List<AiAdvisorExchange> history = const [],
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final q = query.toLowerCase();
    final candidates = _responses[advisorType] ?? const [];
    for (final (keywords, response) in candidates) {
      if (keywords.any((k) => q.contains(k))) return response;
    }
    return _fallback[advisorType] ?? 'Thanks for your question — a program staff member will follow up with more detail.';
  }
}
