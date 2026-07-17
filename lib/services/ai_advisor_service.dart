/// Abstraction over a real LLM-backed advisor API. No real LLM key is wired
/// yet — a production key would swap [MockAiAdvisorService] for a real
/// implementation of this same interface without touching any call site.
/// See docs/DEVELOPMENT_PROGRESS.md's "External API abstraction plan".
abstract class AiAdvisorService {
  /// [advisorType] is one of 'financial' | 'scheme' | 'market', matching
  /// the `ai_advisor_logs.advisor_type` check constraint.
  Future<String> ask({required String advisorType, required String query});
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
  Future<String> ask({required String advisorType, required String query}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final q = query.toLowerCase();
    final candidates = _responses[advisorType] ?? const [];
    for (final (keywords, response) in candidates) {
      if (keywords.any((k) => q.contains(k))) return response;
    }
    return _fallback[advisorType] ?? 'Thanks for your question — a program staff member will follow up with more detail.';
  }
}
