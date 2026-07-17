class ShgInfo {
  static const name = 'Sri Durga Mahila SHG';
  static const regNumber = 'SHG/WGL/2014/00812';
  static const formationDate = '12 Jun 2014';
  static const village = 'Kondapur';
  static const mandal = 'Hanamkonda';
  static const district = 'Warangal';
  static const state = 'Telangana';
  static const memberCount = 12;
  static const totalSavings = 486200;
  static const totalLoans = 312000;
  static const bankName = 'Andhra Pradesh Grameena Vikas Bank';
  static const bankAccount = 'XXXX XXXX 4471';
  static const ifsc = 'APGV0001123';
  static const grade = 'A+';
  static const clf = 'Kakatiya CLF';
  static const vo = 'Hanamkonda Village Organisation';
}

class ShgDocument {
  final String id;
  final String name;
  final String type;
  final String size;
  final String date;
  const ShgDocument({required this.id, required this.name, required this.type, required this.size, required this.date});
}

const documents = <ShgDocument>[
  ShgDocument(id: 'd1', name: 'Registration Certificate', type: 'PDF', size: '1.2 MB', date: '14 Jun 2014'),
  ShgDocument(id: 'd2', name: 'SHG By-laws', type: 'PDF', size: '860 KB', date: '14 Jun 2014'),
  ShgDocument(id: 'd3', name: 'Meeting Record — June 2026', type: 'PDF', size: '340 KB', date: '05 Jun 2026'),
  ShgDocument(id: 'd4', name: 'Bank Passbook Copy', type: 'IMG', size: '2.1 MB', date: '01 Apr 2026'),
  ShgDocument(id: 'd5', name: 'Audit Report FY 2025-26', type: 'PDF', size: '1.8 MB', date: '30 Mar 2026'),
];
