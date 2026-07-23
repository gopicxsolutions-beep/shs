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

/// One multiple-choice question for demo-mode's course quiz. Mirrors the
/// shape of `public.quiz_questions` (question/options/correctIndex) without
/// the DB-only id/courseId columns — [TrainingRepository.fetchQuizQuestions]
/// attaches those when it converts this into a real [QuizQuestion].
class MockQuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  const MockQuizQuestion(this.question, this.options, this.correctIndex);
}

/// Genuine, on-topic starting quiz content for every demo course above,
/// written from each course's own title/topic — NOT a generic question set
/// reused across courses, and NOT a transcription of any real curriculum
/// (there isn't one to transcribe from yet; this is real per-course content,
/// backed by a real schema, that a subject-matter expert should review and
/// extend). Every question tests a genuinely correct, widely-accepted fact
/// about the course's own stated subject.
const quizQuestions = <String, List<MockQuizQuestion>>{
  'co1': [
    MockQuizQuestion(
      'What is the main purpose of a household budget?',
      ['To spend without any planning', 'To plan and track income against expenses', 'To avoid saving money altogether'],
      1,
    ),
    MockQuizQuestion(
      'Which of these is typically a FIXED monthly household expense?',
      ['House rent or loan EMI', 'A one-time festival purchase', 'An occasional gift'],
      0,
    ),
    MockQuizQuestion(
      'Before spending your monthly income, what should you do first?',
      ['Spend on wants immediately', 'List and prioritize essential expenses', 'Ignore expenses until the month ends'],
      1,
    ),
    MockQuizQuestion(
      'What is a good household budgeting habit?',
      ['Spend first and save whatever is left over', 'Never review past spending', 'Set aside savings before other spending'],
      2,
    ),
    MockQuizQuestion(
      'Why track your household expenses?',
      ['To identify where money is going and cut unnecessary spending', 'Tracking expenses serves no real purpose', 'Only to impress other SHG members'],
      0,
    ),
  ],
  'co2': [
    MockQuizQuestion(
      'What does EMI stand for?',
      ['Extra Monthly Income', 'Equated Monthly Installment', 'Estimated Market Interest'],
      1,
    ),
    MockQuizQuestion(
      "Each EMI payment on a loan is generally made up of which two components?",
      ['Principal and interest', 'Only principal, never interest', 'Only interest, never principal'],
      0,
    ),
    MockQuizQuestion(
      "In a standard reducing-balance loan, what typically happens to the interest portion of the EMI over time?",
      ['It increases every month regardless of balance', 'It stays exactly the same amount every month', 'It decreases as the outstanding principal reduces'],
      2,
    ),
    MockQuizQuestion(
      'Why compare the interest rate before taking a loan?',
      ["Interest rate makes no real difference to what you repay", "A higher rate means paying more over the loan's life for the same amount borrowed", 'Only the loan amount matters, never the rate'],
      1,
    ),
    MockQuizQuestion(
      'What is a likely consequence of missing an EMI payment?',
      ['The loan is automatically forgiven', 'There is usually no consequence at all', 'Late fees and/or additional interest charges'],
      2,
    ),
  ],
  'co3': [
    MockQuizQuestion(
      'What is typically the first step before starting a micro enterprise?',
      ['Buying the most expensive equipment available', 'Identifying a viable product/service and your target customers', 'Skipping any planning and starting immediately'],
      1,
    ),
    MockQuizQuestion(
      'Why estimate your startup costs before beginning?',
      ['So you know how much capital you need and can plan financing', 'Startup costs never actually matter', 'So you can spend without any limit'],
      0,
    ),
    MockQuizQuestion(
      "What is 'working capital' in a micro enterprise?",
      ['Money kept permanently unused', 'The funds needed for day-to-day operating expenses', 'Only the value of fixed assets like machinery'],
      1,
    ),
    MockQuizQuestion(
      'Which is a common, legitimate source of funding for a micro enterprise run by SHG members?',
      ['Only unregulated private moneylenders', 'There is no way to fund a micro enterprise', 'SHG internal lending or a bank loan linked to the SHG'],
      2,
    ),
    MockQuizQuestion(
      "Why track a micro enterprise's income/expenses separately from personal household spending?",
      ['It is unnecessary to separate them', 'To actually know whether the business is profitable', 'Only to make the paperwork longer'],
      1,
    ),
  ],
  'co4': [
    MockQuizQuestion(
      'What does UPI stand for?',
      ['Universal Payment Identity', 'United Personal Investment', 'Unified Payments Interface'],
      2,
    ),
    MockQuizQuestion(
      'To pay using a QR code, what do you do?',
      ['Scan the receiver\'s QR code using a UPI app', 'Read out your bank passbook number aloud', 'Print a copy of your EMI schedule'],
      0,
    ),
    MockQuizQuestion(
      'What is a UPI PIN used for?',
      ['Logging into social media', 'Authorizing/confirming a payment you are sending', 'Recovering a forgotten mobile number'],
      1,
    ),
    MockQuizQuestion(
      "Should you share your UPI PIN with someone who claims they need it to 'send' you money?",
      ['Yes, always share it if asked', 'No — a PIN is only needed to send money, never to receive it', 'Only share it if they call from an unknown number'],
      1,
    ),
    MockQuizQuestion(
      'Before confirming a QR payment, what should you check?',
      ['Nothing, just confirm immediately', 'Only the color of the QR code', 'That the amount and receiver name match what you intend to pay'],
      2,
    ),
  ],
  'co5': [
    MockQuizQuestion(
      'Why is posting clear photos of your product important on social media?',
      ["Photos don't matter, only the price does", "It helps potential customers see exactly what they're buying", 'Clear photos usually reduce buyer interest'],
      1,
    ),
    MockQuizQuestion(
      'What is a benefit of posting about your products consistently?',
      ['Consistency has no real effect on sales', 'It keeps your business visible and top-of-mind for buyers', 'It only works if you pay for advertisements'],
      1,
    ),
    MockQuizQuestion(
      "Why respond promptly to a customer's comment or message?",
      ['Delaying replies is generally best practice', 'Customers never expect a response anyway', 'It builds trust and reduces the chance they buy elsewhere'],
      2,
    ),
    MockQuizQuestion(
      'What information should typically appear alongside a product post?',
      ['Price, key details, and how to order/pay', 'Nothing beyond the photo itself', "Only the seller's personal opinions"],
      0,
    ),
    MockQuizQuestion(
      'What is a low-cost way for SHG members to showcase products on social media?',
      ['Only through expensive professional photo shoots', 'Sharing simple photos/videos taken on a phone', 'It always requires hiring a marketing agency'],
      1,
    ),
  ],
  'co6': [
    MockQuizQuestion(
      "At minimum, what should a product's selling price cover?",
      ['Nothing — price can be picked at random', "The total cost of making it, so the business doesn't run at a loss", 'Only the cost of raw materials, ignoring labor'],
      1,
    ),
    MockQuizQuestion(
      'What are the two broad cost categories to add up before pricing a product?',
      ['Only what competitors happen to charge', 'Material/input costs and labor/overhead costs', 'Only what a customer says they will pay'],
      1,
    ),
    MockQuizQuestion(
      "What is 'profit margin'?",
      ['The same thing as total revenue', 'An amount completely unrelated to cost', 'The difference between selling price and total cost'],
      2,
    ),
    MockQuizQuestion(
      'Why compare your price to competitors\' prices in the local market?',
      ['Competitor prices are irrelevant to your business', 'To position your product realistically while still covering your costs', 'To always price higher regardless of your own costs'],
      1,
    ),
    MockQuizQuestion(
      'If raw material costs increase, what should you consider doing?',
      ['Immediately stop selling the product', 'Ignore it and keep the price exactly the same forever', 'Reviewing and possibly adjusting your selling price to protect margin'],
      2,
    ),
  ],
};
