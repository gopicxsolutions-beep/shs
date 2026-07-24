/// Mirrors a row in `public.ai_advisor_logs`.
class AiAdvisorLog {
  final String id;
  final String memberId;
  final String advisorType; // financial | scheme | market
  final String query;
  final String? response;
  final DateTime createdAt;

  const AiAdvisorLog({
    required this.id,
    required this.memberId,
    required this.advisorType,
    required this.query,
    this.response,
    required this.createdAt,
  });

  factory AiAdvisorLog.fromMap(Map<String, dynamic> map) => AiAdvisorLog(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        advisorType: map['advisor_type'] as String,
        query: map['query'] as String,
        response: map['response'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

/// One prior question+answer turn from the *current* chat session, forwarded
/// alongside a new query so an AI Advisor has real cross-turn memory (see
/// `AiAdvisorRepository`'s session-scoped history and
/// `ai-advisor-proxy/history.ts` server-side). Held only in memory for the
/// lifetime of one open `AiAdvisorChatPage` — never persisted here; the
/// persisted `AiAdvisorLog` rows above remain the sole source of truth for
/// what's shown when the page is reopened.
class AiAdvisorExchange {
  final String query;
  final String response;
  const AiAdvisorExchange({required this.query, required this.response});

  Map<String, String> toJson() => {'query': query, 'response': response};
}
