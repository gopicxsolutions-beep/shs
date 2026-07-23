import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/loan.dart';
import '../../repositories/loan_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

const _statusTones = <String, BadgeTone>{
  'pending': BadgeTone.warning,
  'active': BadgeTone.brand,
  'overdue': BadgeTone.danger,
  'closed': BadgeTone.success,
  'rejected': BadgeTone.neutral,
};

class LoanStatementPage extends StatelessWidget {
  const LoanStatementPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final memberId = context.watch<AppState>().profile?.id;
    final repo = LoanRepository();

    return Scaffold(
      appBar: PageHeader(title: l10n.loanStatementTitle),
      body: AppAsyncBuilder<List<Loan>>(
        future: () => repo.fetchForMember(memberId),
        builder: (context, loans) {
          if (loans.isEmpty) {
            return AppEmptyState(icon: Icons.account_balance_rounded, message: l10n.loanStatementEmpty);
          }
          final totalBorrowed = loans.fold<num>(0, (s, l) => s + l.amount);
          final totalOutstanding = loans.where((l) => l.status == 'active' || l.status == 'overdue').fold<num>(0, (s, l) => s + l.outstanding);
          final totalRepaid = totalBorrowed - loans.fold<num>(0, (s, l) => s + l.outstanding);

          // A CustomScrollView/Sliver split (not a plain ListView with
          // `...loans.map(...)`) so the loan list below is genuinely lazily
          // built (SliverList.builder) instead of every row being built
          // eagerly regardless of scroll position.
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: AppCard(
                        gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(l10n.loanStatementTotalOutstandingLabel, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                                const SizedBox(height: 4),
                                Text(
                                  '₹${NumberFormat('#,##,##0', 'en_IN').format(totalOutstanding)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                              ]),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                Text(l10n.loanStatementLoanCount(loans.length), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.loanStatementRepaidAmount(NumberFormat('#,##,##0', 'en_IN').format(totalRepaid)),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                                ),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    SliverList.builder(
                      itemCount: loans.length,
                      itemBuilder: (context, index) {
                        final l = loans[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            onTap: () => context.go(Paths.loanDetail(l.id)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Expanded(child: Text(l.purpose, style: AppTheme.sans(13, weight: FontWeight.w700))),
                                  AppBadge(text: l.status, tone: _statusTones[l.status] ?? BadgeTone.neutral),
                                ]),
                                const SizedBox(height: 8),
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Flexible(child: Text(l10n.loanStatementAmountLabel(NumberFormat('#,##,##0', 'en_IN').format(l.amount)), overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500))),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      l10n.loanStatementOutstandingAmount(NumberFormat('#,##,##0', 'en_IN').format(l.outstanding)),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.right,
                                      style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600),
                                    ),
                                  ),
                                ]),
                                if (l.disbursedOn != null) ...[
                                  const SizedBox(height: 4),
                                  Text(l10n.loanStatementDisbursedOn(DateFormat('dd MMM yyyy').format(l.disbursedOn!)), style: AppTheme.sans(11, color: Neutral.c400)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
