export interface Course {
  id: string
  title: string
  topic: 'Financial Literacy' | 'Entrepreneurship' | 'Digital Payments' | 'Marketing'
  format: 'Video' | 'PDF' | 'Audio'
  duration: string
  progress: number
  certified?: boolean
}

export const courses: Course[] = [
  { id: 'co1', title: 'Basics of Household Budgeting', topic: 'Financial Literacy', format: 'Video', duration: '18 min', progress: 100, certified: true },
  { id: 'co2', title: 'Understanding Interest & EMI', topic: 'Financial Literacy', format: 'Video', duration: '22 min', progress: 60 },
  { id: 'co3', title: 'Starting a Micro Enterprise', topic: 'Entrepreneurship', format: 'PDF', duration: '12 pages', progress: 30 },
  { id: 'co4', title: 'UPI & QR Payments Made Easy', topic: 'Digital Payments', format: 'Video', duration: '15 min', progress: 0 },
  { id: 'co5', title: 'Selling on Social Media', topic: 'Marketing', format: 'Audio', duration: '10 min', progress: 0 },
  { id: 'co6', title: 'Costing & Pricing Your Products', topic: 'Marketing', format: 'Video', duration: '20 min', progress: 100, certified: true },
]

export const certificates = [
  { id: 'ce1', title: 'Basics of Household Budgeting', date: '02 May 2026', score: 92 },
  { id: 'ce2', title: 'Costing & Pricing Your Products', date: '18 May 2026', score: 88 },
]
