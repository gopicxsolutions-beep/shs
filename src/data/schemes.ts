export interface Scheme {
  id: string
  name: string
  fullName: string
  agency: string
  benefit: string
  eligibility: string[]
  status?: 'not_applied' | 'applied' | 'under_review' | 'approved' | 'rejected'
  deadline?: string
}

export const schemes: Scheme[] = [
  {
    id: 'sc1',
    name: 'DAY-NRLM',
    fullName: 'Deendayal Antyodaya Yojana - National Rural Livelihoods Mission',
    agency: 'Ministry of Rural Development',
    benefit: 'Revolving fund of ₹15,000–₹30,000 and interest subvention on SHG loans',
    eligibility: ['SHG registered for 6+ months', 'BPL / rural household', 'Active savings record'],
    status: 'approved',
  },
  {
    id: 'sc2',
    name: 'PMEGP',
    fullName: 'Prime Minister’s Employment Generation Programme',
    agency: 'KVIC / Ministry of MSME',
    benefit: 'Subsidy up to 35% on project cost for new micro-enterprises',
    eligibility: ['Age 18+', 'No prior PMEGP subsidy availed', 'Project cost up to ₹50 lakh'],
    status: 'under_review',
    deadline: '15 Jul 2026',
  },
  {
    id: 'sc3',
    name: 'MUDRA',
    fullName: 'Micro Units Development & Refinance Agency Yojana',
    agency: 'Ministry of Finance',
    benefit: 'Collateral-free loans up to ₹10 lakh under Shishu/Kishor/Tarun',
    eligibility: ['Non-farm income generating activity', 'Existing or new micro business'],
    status: 'applied',
    deadline: '10 Jul 2026',
  },
  {
    id: 'sc4',
    name: 'Stand-Up India',
    fullName: 'Stand-Up India Scheme',
    agency: 'Department of Financial Services',
    benefit: 'Bank loans ₹10 lakh – ₹1 crore for greenfield enterprises',
    eligibility: ['Women / SC/ST entrepreneur', 'Greenfield project', 'Non-individual borrowers eligible'],
    status: 'not_applied',
  },
  {
    id: 'sc5',
    name: 'NRLM RF',
    fullName: 'Revolving Fund Support',
    agency: 'State Rural Livelihoods Mission',
    benefit: 'One-time grant support to strengthen SHG corpus',
    eligibility: ['SHG grading of B or above', 'Regular meeting & savings record'],
    status: 'not_applied',
  },
]
