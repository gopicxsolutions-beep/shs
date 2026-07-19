import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/marketplace.dart';
import '../../repositories/marketplace_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class MarketplaceReviewsPage extends StatelessWidget {
  const MarketplaceReviewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = MarketplaceRepository();
    final sellerId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Reviews'),
      body: AppAsyncBuilder<List<Review>>(
        future: () => repo.fetchReviewsForSeller(sellerId),
        builder: (context, reviews) {
          if (reviews.isEmpty) {
            return const AppEmptyState(icon: Icons.star_border_rounded, message: 'No reviews on your products yet');
          }
          final avg = reviews.fold<num>(0, (s, r) => s + r.rating) / reviews.length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Row(children: [
                  Icon(Icons.star_rounded, color: Gold.c500, size: 28),
                  const SizedBox(width: 8),
                  Text(avg.toStringAsFixed(1), style: AppTheme.display(22)),
                  const SizedBox(width: 8),
                  Text('from ${reviews.length} review${reviews.length == 1 ? '' : 's'}', style: AppTheme.sans(12, color: Neutral.c500)),
                ]),
              ),
              const SizedBox(height: 16),
              AppCard(
                padded: false,
                child: Column(
                  children: reviews.map((r) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(r.reviewerName, style: AppTheme.sans(12, weight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              Semantics(
                                label: '${r.rating} out of 5 stars',
                                child: ExcludeSemantics(
                                  child: Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_border_rounded, size: 14, color: Gold.c500))),
                                ),
                              ),
                            ]),
                            if (r.comment != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.comment!, style: AppTheme.sans(12, color: Neutral.c600))),
                          ],
                        ),
                      )).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
