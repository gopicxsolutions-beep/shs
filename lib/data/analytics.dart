class Kpis {
  static const totalSHGs = 186;
  static const activeMembers = 2142;
  static const totalSavings = 48600000;
  static const loansDisbursed = 31200000;
  static const recoveryRate = 94.2;
  static const trainingCompletion = 78;
}

class VillageShgs {
  final String village;
  final int shgs;
  final int savings;
  const VillageShgs(this.village, this.shgs, this.savings);
}

const villageWiseSHGs = <VillageShgs>[
  VillageShgs('Kondapur', 24, 6100000),
  VillageShgs('Hanamkonda', 31, 8300000),
  VillageShgs('Warangal Rural', 28, 7200000),
  VillageShgs('Narsampet', 19, 4600000),
  VillageShgs('Parkal', 22, 5400000),
];

class MonitoredShg {
  final String id;
  final String name;
  final String village;
  final String grade;
  final int members;
  final int savings;
  final int health;
  const MonitoredShg(this.id, this.name, this.village, this.grade, this.members, this.savings, this.health);
}

const shgsForMonitoring = <MonitoredShg>[
  MonitoredShg('g1', 'Sri Durga Mahila SHG', 'Kondapur', 'A+', 12, 486200, 96),
  MonitoredShg('g2', 'Jai Bhavani SHG', 'Kondapur', 'A', 11, 402100, 90),
  MonitoredShg('g3', 'Sai Mahila Sangham', 'Hanamkonda', 'B+', 10, 318500, 78),
  MonitoredShg('g4', 'Gayatri SHG', 'Hanamkonda', 'A', 13, 445300, 88),
  MonitoredShg('g5', 'Rythu Mahila Group', 'Warangal Rural', 'C', 9, 198000, 58),
];
