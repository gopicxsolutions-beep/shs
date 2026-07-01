export interface Member {
  id: string
  name: string
  mobile: string
  aadhaar: string
  role: string
  joiningDate: string
  savings: number
  loanOutstanding: number
  attendance: number
  status: 'active' | 'inactive'
}

export const members: Member[] = [
  { id: 'm1', name: 'Lakshmi Devi', mobile: '98765 43210', aadhaar: 'XXXX XXXX 4821', role: 'President', joiningDate: '12 Jun 2014', savings: 48200, loanOutstanding: 22000, attendance: 96, status: 'active' },
  { id: 'm2', name: 'Padma Reddy', mobile: '98765 11223', aadhaar: 'XXXX XXXX 7742', role: 'Secretary', joiningDate: '12 Jun 2014', savings: 41500, loanOutstanding: 0, attendance: 100, status: 'active' },
  { id: 'm3', name: 'Rajeshwari', mobile: '87654 22114', aadhaar: 'XXXX XXXX 1290', role: 'Treasurer', joiningDate: '03 Aug 2015', savings: 39800, loanOutstanding: 18500, attendance: 92, status: 'active' },
  { id: 'm4', name: 'Anasuya', mobile: '90123 45671', aadhaar: 'XXXX XXXX 3345', role: 'Member', joiningDate: '19 Jan 2016', savings: 36200, loanOutstanding: 0, attendance: 88, status: 'active' },
  { id: 'm5', name: 'Bhavani', mobile: '91234 56782', aadhaar: 'XXXX XXXX 9987', role: 'Member', joiningDate: '19 Jan 2016', savings: 33500, loanOutstanding: 12000, attendance: 84, status: 'active' },
  { id: 'm6', name: 'Chandrakala', mobile: '92345 67893', aadhaar: 'XXXX XXXX 6612', role: 'Member', joiningDate: '05 Mar 2017', savings: 30100, loanOutstanding: 0, attendance: 90, status: 'active' },
  { id: 'm7', name: 'Durga Bhavani', mobile: '93456 78904', aadhaar: 'XXXX XXXX 5523', role: 'Member', joiningDate: '05 Mar 2017', savings: 28700, loanOutstanding: 9000, attendance: 78, status: 'active' },
  { id: 'm8', name: 'Eswari', mobile: '94567 89015', aadhaar: 'XXXX XXXX 8871', role: 'Member', joiningDate: '22 Sep 2018', savings: 26400, loanOutstanding: 0, attendance: 95, status: 'active' },
  { id: 'm9', name: 'Gowramma', mobile: '95678 90126', aadhaar: 'XXXX XXXX 2210', role: 'Member', joiningDate: '22 Sep 2018', savings: 24800, loanOutstanding: 15500, attendance: 70, status: 'active' },
  { id: 'm10', name: 'Hemalatha', mobile: '96789 01237', aadhaar: 'XXXX XXXX 4456', role: 'Member', joiningDate: '11 Nov 2019', savings: 22100, loanOutstanding: 0, attendance: 82, status: 'active' },
  { id: 'm11', name: 'Indira', mobile: '97890 12348', aadhaar: 'XXXX XXXX 7789', role: 'Member', joiningDate: '11 Nov 2019', savings: 20300, loanOutstanding: 0, attendance: 91, status: 'active' },
  { id: 'm12', name: 'Jyothi', mobile: '98901 23459', aadhaar: 'XXXX XXXX 3312', role: 'Member', joiningDate: '02 Feb 2021', savings: 18900, loanOutstanding: 8000, attendance: 60, status: 'inactive' },
]
