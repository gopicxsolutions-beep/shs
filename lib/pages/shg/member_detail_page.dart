import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../layout/page_header.dart';
import '../../models/shg.dart';
import '../../repositories/loan_repository.dart';
import '../../repositories/savings_repository.dart';
import '../../repositories/shg_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_card.dart';

class _MemberDetail {
  final Member? member;
  final num totalSavings;
  final num totalOutstanding;
  const _MemberDetail(this.member, this.totalSavings, this.totalOutstanding);
}

class MemberDetailPage extends StatelessWidget {
  final String memberId;
  const MemberDetailPage({super.key, required this.memberId});

  Future<_MemberDetail> _load() async {
    final shgRepo = ShgRepository();
    final savingsRepo = SavingsRepository();
    final loanRepo = LoanRepository();
    final member = await shgRepo.fetchMember(memberId);
    final savings = await savingsRepo.fetchForMember(memberId);
    final loans = await loanRepo.fetchForMember(memberId);
    final totalSavings = savings.fold<num>(0, (s, e) => s + e.amount);
    final totalOutstanding = loans.where((l) => l.status == 'active' || l.status == 'overdue').fold<num>(0, (s, l) => s + l.outstanding);
    return _MemberDetail(member, totalSavings, totalOutstanding);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'Member Detail'),
      body: AppAsyncBuilder<_MemberDetail>(
        future: _load,
        builder: (context, detail) {
          final member = detail.member;
          if (member == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This member could not be found');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(children: [
                  AppAvatar(name: member.name, size: 72),
                  const SizedBox(height: 12),
                  Text(member.name, style: AppTheme.display(18)),
                  const SizedBox(height: 4),
                  if (member.role != 'member') AppBadge(text: member.role, tone: BadgeTone.brand),
                ]),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: StatCard(label: 'Total Savings', value: '₹${NumberFormat('#,##,##0', 'en_IN').format(detail.totalSavings)}', tone: StatTone.brand, icon: Icons.account_balance_wallet_rounded)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Loan Outstanding', value: '₹${NumberFormat('#,##,##0', 'en_IN').format(detail.totalOutstanding)}', tone: StatTone.gold, icon: Icons.account_balance_rounded)),
              ]),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Contact'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row('Mobile', member.mobile ?? '—'),
                    const SizedBox(height: 8),
                    _row('Village', member.village ?? '—'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // `value` (a member's mobile number / village name) is real, unbounded
  // data with no flex protection at all, so at a scaled-up accessibility
  // text size it — combined with the label — could overflow the row.
  // `Flexible`+ellipsis on both sides (same pattern as the sibling `_row`
  // helper in shg_home_page.dart) keeps both visible instead of throwing.
  Widget _row(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500))),
          const SizedBox(width: 8),
          Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: AppTheme.sans(12, weight: FontWeight.w700))),
        ],
      );
}
