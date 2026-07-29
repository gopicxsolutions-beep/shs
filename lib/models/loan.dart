import '../l10n/gen/app_localizations.dart';
import '../widgets/app_badge.dart';

/// Was independently copy-pasted in loans_home_page.dart, loan_detail_page.dart,
/// and loan_tracking_page.dart — extracted here (round 190/iteration 18) before
/// a 4th copy was about to be added in loan_statement_page.dart.
String loanStatusLabel(String status, AppLocalizations l10n) => switch (status) {
      'pending' => l10n.loanStatusPending,
      'active' => l10n.loanStatusActive,
      'overdue' => l10n.loanStatusOverdue,
      'closed' => l10n.loanStatusClosed,
      'rejected' => l10n.loanStatusRejected,
      _ => status,
    };

const loanStatusTones = <String, BadgeTone>{
  'pending': BadgeTone.warning,
  'active': BadgeTone.brand,
  'overdue': BadgeTone.danger,
  'closed': BadgeTone.success,
  'rejected': BadgeTone.neutral,
};

/// Mirrors a row in `public.loans` (joined with the member's name).
class Loan {
  final String id;
  final String memberId;
  final String memberName;
  final String purpose;
  final num amount;
  final num outstanding;
  final num emi;
  final int tenureMonths;
  final DateTime? disbursedOn;
  final String status; // pending | approved | rejected | active | closed | overdue
  final DateTime? nextDueDate;
  // Only populated when the query joins `shgs(name)` (today: only
  // LoanRepository.fetchAllForStaff()'s platform-wide portfolio fetch) —
  // null everywhere else, including demo mode. Lets the staff-facing
  // cross-SHG list/approval queue tell loans from different SHGs apart,
  // which a plain member-name/purpose row can't.
  final String? shgName;
  // Only populated when the query embeds `profiles!decided_by(name)` (see
  // migration 0082 — decided_by/decided_at added to mirror the same
  // attribution `scheme_applications`/`support_tickets`/`shg_join_requests`
  // already had). Null for a still-pending loan, or when the query doesn't
  // embed it.
  final String? decidedByName;
  final DateTime? decidedAt;

  const Loan({
    required this.id,
    required this.memberId,
    required this.memberName,
    required this.purpose,
    required this.amount,
    required this.outstanding,
    required this.emi,
    required this.tenureMonths,
    this.disbursedOn,
    required this.status,
    this.nextDueDate,
    this.shgName,
    this.decidedByName,
    this.decidedAt,
  });

  factory Loan.fromMap(Map<String, dynamic> map) => Loan(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        memberName: (map['member_profile'] as Map<String, dynamic>?)?['name'] as String? ?? 'Member',
        purpose: map['purpose'] as String,
        amount: map['amount'] as num,
        outstanding: map['outstanding'] as num,
        emi: map['emi'] as num,
        tenureMonths: map['tenure_months'] as int,
        disbursedOn: map['disbursed_on'] != null ? DateTime.parse(map['disbursed_on'] as String) : null,
        status: map['status'] as String,
        nextDueDate: map['next_due_date'] != null ? DateTime.parse(map['next_due_date'] as String) : null,
        shgName: (map['shgs'] as Map<String, dynamic>?)?['name'] as String?,
        decidedByName: (map['decided_by_profile'] as Map<String, dynamic>?)?['name'] as String?,
        decidedAt: map['decided_at'] != null ? DateTime.parse(map['decided_at'] as String) : null,
      );
}

/// Mirrors a row in `public.loan_payments`.
class LoanPayment {
  final String id;
  final String loanId;
  final num amount;
  final DateTime paidOn;

  const LoanPayment({required this.id, required this.loanId, required this.amount, required this.paidOn});

  factory LoanPayment.fromMap(Map<String, dynamic> map) => LoanPayment(
        id: map['id'] as String,
        loanId: map['loan_id'] as String,
        amount: map['amount'] as num,
        paidOn: DateTime.parse(map['paid_on'] as String),
      );
}
