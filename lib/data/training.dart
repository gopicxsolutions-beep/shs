class Course {
  final String id;
  final String title;
  final String topic;
  final String format;
  final String duration;
  final int progress;
  final bool certified;
  const Course({
    required this.id,
    required this.title,
    required this.topic,
    required this.format,
    required this.duration,
    required this.progress,
    this.certified = false,
  });
}

const courses = <Course>[
  Course(id: 'co1', title: 'Basics of Household Budgeting', topic: 'Financial Literacy', format: 'Video', duration: '18 min', progress: 100, certified: true),
  Course(id: 'co2', title: 'Understanding Interest & EMI', topic: 'Financial Literacy', format: 'Video', duration: '22 min', progress: 60),
  Course(id: 'co3', title: 'Starting a Micro Enterprise', topic: 'Entrepreneurship', format: 'PDF', duration: '12 pages', progress: 30),
  Course(id: 'co4', title: 'UPI & QR Payments Made Easy', topic: 'Digital Payments', format: 'Video', duration: '15 min', progress: 0),
  Course(id: 'co5', title: 'Selling on Social Media', topic: 'Marketing', format: 'Audio', duration: '10 min', progress: 0),
  Course(id: 'co6', title: 'Costing & Pricing Your Products', topic: 'Marketing', format: 'Video', duration: '20 min', progress: 100, certified: true),
];
