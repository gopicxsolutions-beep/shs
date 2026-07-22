import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../layout/page_header.dart';
import '../../models/report.dart';
import '../../repositories/report_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class FederationVillagesPage extends StatelessWidget {
  const FederationVillagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = ReportRepository();

    return Scaffold(
      appBar: const PageHeader(title: 'Village-wise SHGs'),
      body: AppAsyncBuilder<List<VillageShgGroup>>(
        future: repo.fetchVillageWiseShgs,
        builder: (context, groups) {
          if (groups.isEmpty) {
            return const AppEmptyState(icon: Icons.apartment_rounded, message: 'No SHGs registered yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final g = groups[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.village, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(14, weight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${g.shgCount} SHGs', style: AppTheme.sans(12, color: Neutral.c500)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // The switch from a raw `${g.totalSavings}` to a
                      // comma-grouped NumberFormat string (matching how every
                      // other total-savings figure in the app is displayed)
                      // adds 1-2 characters at this scale (lakhs) — enough to
                      // overflow this row's fixed width without a Flexible
                      // wrapper, since the sibling Column had no Expanded
                      // either. `all_routes_smoke_test.dart` caught this via
                      // a real RenderFlex overflow on this route.
                      Flexible(
                        child: Text(
                          '₹${NumberFormat('#,##,##0', 'en_IN').format(g.totalSavings)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: AppTheme.sans(14, weight: FontWeight.w700, color: Brand.c600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
