import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/marketplace.dart';
import '../../repositories/marketplace_repository.dart';
import '../../routes/paths.dart';
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.marketplaceReviewsTitle),
      body: AppAsyncBuilder<List<Review>>(
        future: () => repo.fetchReviewsForSeller(sellerId),
        builder: (context, reviews) {
          if (reviews.isEmpty) {
            return AppEmptyState(icon: Icons.star_border_rounded, message: l10n.marketplaceReviewsEmpty);
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
                  Flexible(child: Text(l10n.marketplaceReviewsFromCount(reviews.length), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500))),
                ]),
              ),
              const SizedBox(height: 16),
              AppCard(
                padded: false,
                child: Column(
                  children: reviews.map((r) => InkWell(
                        // Missing feature: a seller with more than one
                        // listing had no way to tell which product a
                        // review was even about — tapping through to it is
                        // a natural extension of now actually showing the
                        // name at all.
                        onTap: () => context.go(Paths.marketplaceProduct(r.productId)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (r.productName != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(r.productName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(11, weight: FontWeight.w700, color: Brand.c600)),
                                ),
                              Row(children: [
                                Flexible(child: Text(r.reviewerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700))),
                                const SizedBox(width: 8),
                                Semantics(
                                  label: l10n.marketplaceReviewsRatingSemantics(r.rating),
                                  child: ExcludeSemantics(
                                    child: Row(children: List.generate(5, (i) => Icon(i < r.rating ? Icons.star_rounded : Icons.star_border_rounded, size: 14, color: Gold.c500))),
                                  ),
                                ),
                              ]),
                              if (r.comment != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(r.comment!, style: AppTheme.sans(12, color: Neutral.c600))),
                            ],
                          ),
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
