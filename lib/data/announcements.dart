class Announcement {
  final String id;
  final String title;
  final String body;
  final String category; // Circular | Meeting | Training | Scheme
  final String date;
  final bool read;
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.date,
    required this.read,
  });
}

const announcements = <Announcement>[
  Announcement(id: 'an1', title: 'DAY-NRLM interest subvention circular', body: 'New interest subvention rates effective from July 2026 for SHGs with A grade.', category: 'Circular', date: '29 Jun 2026', read: false),
  Announcement(id: 'an2', title: 'Monthly meeting scheduled for 5 Jul', body: 'All members requested to attend the monthly review meeting at Anganwadi Centre, 4 PM.', category: 'Meeting', date: '28 Jun 2026', read: false),
  Announcement(id: 'an3', title: 'Digital Payments training on 12 Jul', body: 'CRP will conduct a hands-on UPI & QR payments training session.', category: 'Training', date: '27 Jun 2026', read: true),
  Announcement(id: 'an4', title: 'MUDRA loan camp at Mandal office', body: 'Bank officials will be available on 8 Jul for MUDRA loan applications.', category: 'Scheme', date: '24 Jun 2026', read: true),
  Announcement(id: 'an5', title: 'SHG grading exercise next week', body: 'CRP will visit for the annual SHG grading assessment.', category: 'Circular', date: '20 Jun 2026', read: true),
];
