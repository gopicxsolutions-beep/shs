class LivelihoodActivityMock {
  final String id;
  final String memberName;
  final String activityType;
  final String description;
  final int investment;
  final int revenue;
  final String status; // planned | active | completed
  const LivelihoodActivityMock({
    required this.id,
    required this.memberName,
    required this.activityType,
    required this.description,
    required this.investment,
    required this.revenue,
    required this.status,
  });
}

const livelihoodActivities = <LivelihoodActivityMock>[
  LivelihoodActivityMock(id: 'lh1', memberName: 'Lakshmi Devi', activityType: 'Dairy', description: 'Milch cow rearing — 2 cows', investment: 30000, revenue: 42000, status: 'active'),
  LivelihoodActivityMock(id: 'lh2', memberName: 'Rajeshwari', activityType: 'Tailoring', description: 'Boutique tailoring unit', investment: 25000, revenue: 18000, status: 'active'),
  LivelihoodActivityMock(id: 'lh3', memberName: 'Bhavani', activityType: 'Retail', description: 'Kirana shop', investment: 15000, revenue: 22000, status: 'active'),
  LivelihoodActivityMock(id: 'lh4', memberName: 'Durga Bhavani', activityType: 'Poultry', description: 'Poultry farming — 100 birds', investment: 12000, revenue: 9000, status: 'planned'),
  LivelihoodActivityMock(id: 'lh5', memberName: 'Gowramma', activityType: 'Agriculture', description: 'Vegetable cultivation', investment: 20000, revenue: 31000, status: 'completed'),
];
