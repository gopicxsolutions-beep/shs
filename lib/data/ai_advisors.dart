class MockAdvisorLog {
  final String advisorType;
  final String query;
  final String response;
  const MockAdvisorLog({required this.advisorType, required this.query, required this.response});
}

const mockAdvisorLogs = <MockAdvisorLog>[
  MockAdvisorLog(
    advisorType: 'financial',
    query: 'How much should I save every week?',
    response: 'Aim to save a fixed amount every meeting rather than a variable one — even ₹100/week builds a steady corpus your group can lend against.',
  ),
  MockAdvisorLog(
    advisorType: 'scheme',
    query: 'Am I eligible for a MUDRA loan?',
    response: 'MUDRA loans are collateral-free up to ₹10 lakh for small businesses. Check the Eligibility Checker under Schemes to confirm for your SHG grade.',
  ),
];
