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
