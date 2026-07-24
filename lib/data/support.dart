class MockTicket {
  final String id;
  final String subject;
  final String description;
  final String status;
  final String date;
  const MockTicket({required this.id, required this.subject, required this.description, required this.status, required this.date});
}

class MockMessage {
  final String ticketId;
  final String sender; // 'me' | 'support'
  final String body;
  final String time;
  const MockMessage({required this.ticketId, required this.sender, required this.body, required this.time});
}

const mockTickets = <MockTicket>[
  MockTicket(id: 'tk1', subject: 'Loan disbursement delay', description: 'My approved loan has not been disbursed yet, it has been 10 days.', status: 'in_progress', date: '10 Jul 2026'),
  MockTicket(id: 'tk2', subject: 'Unable to see last month savings', description: 'The savings ledger is not showing June entries.', status: 'resolved', date: '2 Jul 2026'),
  MockTicket(id: 'tk3', subject: 'Wrong bank account on file', description: 'My bank account number is incorrect in the SHG records.', status: 'open', date: '14 Jul 2026'),
];

const mockMessages = <MockMessage>[
  MockMessage(ticketId: 'tk1', sender: 'me', body: 'My approved loan has not been disbursed yet, it has been 10 days.', time: '10 Jul, 9:02 AM'),
  MockMessage(ticketId: 'tk1', sender: 'support', body: 'Thanks for reporting — we are checking with the bank on this. Will update you within 2 working days.', time: '10 Jul, 11:40 AM'),
  MockMessage(ticketId: 'tk2', sender: 'me', body: 'The savings ledger is not showing June entries.', time: '2 Jul, 4:15 PM'),
  MockMessage(ticketId: 'tk2', sender: 'support', body: 'This has been fixed — please refresh the app and check again.', time: '3 Jul, 10:05 AM'),
  MockMessage(ticketId: 'tk2', sender: 'me', body: 'Yes, I can see them now. Thank you!', time: '3 Jul, 10:20 AM'),
  MockMessage(ticketId: 'tk3', sender: 'me', body: 'My bank account number is incorrect in the SHG records.', time: '14 Jul, 6:30 PM'),
];

class MockFaq {
  final String question;
  final String answer;
  const MockFaq({required this.question, required this.answer});
}

const mockFaqs = <MockFaq>[
  MockFaq(question: 'How do I add a savings entry?', answer: 'Go to Savings > Add Entry, enter the amount and date, then submit.'),
  MockFaq(question: 'How do I apply for a loan?', answer: 'Go to Loans > Apply, fill in the amount and purpose, then submit for leader approval.'),
  MockFaq(question: 'How do I check my SHG grade?', answer: 'Your SHG grade is shown on the My SHG screen along with member details.'),
  MockFaq(question: 'Who can post announcements?', answer: 'Only your SHG leader or program staff (CRP/CLF/Admin) can post announcements.'),
  MockFaq(question: 'How do I raise a support ticket?', answer: 'Go to Support > Raise a Ticket, describe your issue, and submit. You can track replies in My Tickets.'),
];
