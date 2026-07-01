export interface Meeting {
  id: string
  date: string
  time: string
  venue: string
  agenda: string
  attendance: number
  total: number
  status: 'upcoming' | 'completed'
}

export const meetings: Meeting[] = [
  { id: 'mt1', date: '05 Jul 2026', time: '4:00 PM', venue: "Anganwadi Centre, Kondapur", agenda: 'Monthly savings review & loan applications', attendance: 0, total: 12, status: 'upcoming' },
  { id: 'mt2', date: '28 Jun 2026', time: '4:00 PM', venue: "Anganwadi Centre, Kondapur", agenda: 'Weekly savings collection & attendance', attendance: 11, total: 12, status: 'completed' },
  { id: 'mt3', date: '21 Jun 2026', time: '4:00 PM', venue: "Anganwadi Centre, Kondapur", agenda: 'Loan repayment discussion', attendance: 12, total: 12, status: 'completed' },
  { id: 'mt4', date: '14 Jun 2026', time: '4:00 PM', venue: "Anganwadi Centre, Kondapur", agenda: 'DAY-NRLM scheme awareness session', attendance: 10, total: 12, status: 'completed' },
  { id: 'mt5', date: '07 Jun 2026', time: '4:00 PM', venue: "Anganwadi Centre, Kondapur", agenda: 'Weekly savings & training update', attendance: 9, total: 12, status: 'completed' },
]

export const minutesOfMeeting = {
  decisions: [
    'Approved loan of ₹20,000 to Gowramma for agriculture inputs',
    'Increased weekly savings from ₹300 to ₹500 from July',
    'Scheduled financial literacy training for 12 Jul 2026',
  ],
  actionItems: [
    { task: 'Submit MUDRA loan application documents', owner: 'Anasuya', due: '10 Jul 2026' },
    { task: 'Collect pending savings from June', owner: 'Padma Reddy', due: '05 Jul 2026' },
    { task: 'Update bank passbook entries', owner: 'Rajeshwari', due: '08 Jul 2026' },
  ],
}
