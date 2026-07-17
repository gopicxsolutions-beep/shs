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
  });

  factory Loan.fromMap(Map<String, dynamic> map) => Loan(
        id: map['id'] as String,
        memberId: map['member_id'] as String,
        memberName: (map['profiles'] as Map<String, dynamic>?)?['name'] as String? ?? 'Member',
        purpose: map['purpose'] as String,
        amount: map['amount'] as num,
        outstanding: map['outstanding'] as num,
        emi: map['emi'] as num,
        tenureMonths: map['tenure_months'] as int,
        disbursedOn: map['disbursed_on'] != null ? DateTime.parse(map['disbursed_on'] as String) : null,
        status: map['status'] as String,
        nextDueDate: map['next_due_date'] != null ? DateTime.parse(map['next_due_date'] as String) : null,
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
