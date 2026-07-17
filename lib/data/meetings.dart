class Meeting {
  final String id;
  final String date;
  final String time;
  final String venue;
  final String agenda;
  final int attendance;
  final int total;
  final String status; // upcoming | completed
  const Meeting({
    required this.id,
    required this.date,
    required this.time,
    required this.venue,
    required this.agenda,
    required this.attendance,
    required this.total,
    required this.status,
  });
}

const meetings = <Meeting>[
  Meeting(id: 'mt1', date: '05 Jul 2026', time: '4:00 PM', venue: 'Anganwadi Centre, Kondapur', agenda: 'Monthly savings review & loan applications', attendance: 0, total: 12, status: 'upcoming'),
  Meeting(id: 'mt2', date: '28 Jun 2026', time: '4:00 PM', venue: 'Anganwadi Centre, Kondapur', agenda: 'Weekly savings collection & attendance', attendance: 11, total: 12, status: 'completed'),
  Meeting(id: 'mt3', date: '21 Jun 2026', time: '4:00 PM', venue: 'Anganwadi Centre, Kondapur', agenda: 'Loan repayment discussion', attendance: 12, total: 12, status: 'completed'),
  Meeting(id: 'mt4', date: '14 Jun 2026', time: '4:00 PM', venue: 'Anganwadi Centre, Kondapur', agenda: 'DAY-NRLM scheme awareness session', attendance: 10, total: 12, status: 'completed'),
  Meeting(id: 'mt5', date: '07 Jun 2026', time: '4:00 PM', venue: 'Anganwadi Centre, Kondapur', agenda: 'Weekly savings & training update', attendance: 9, total: 12, status: 'completed'),
];
