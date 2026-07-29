import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/analytics.dart';
import '../../models/paged_result.dart';
import '../../repositories/analytics_repository.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/progress_bar.dart';

const _gradeTone = <String, BadgeTone>{'A+': BadgeTone.success, 'A': BadgeTone.brand, 'B+': BadgeTone.brand, 'B': BadgeTone.warning, 'C': BadgeTone.danger};

class AnalyticsShgListPage extends StatefulWidget {
  const AnalyticsShgListPage({super.key});
  @override
  State<AnalyticsShgListPage> createState() => _AnalyticsShgListPageState();
}

class _AnalyticsShgListPageState extends State<AnalyticsShgListPage> {
  final _repo = AnalyticsRepository();
  final GlobalKey<AppAsyncBuilderState<PagedResult<ShgHealth>>> _key = GlobalKey();

  // Same appendable-local-copy shape as AdminUsersPage/AdminShgsPage — see
  // those pages' doc comments for why the builder below renders these
  // instead of the AppAsyncBuilder's own snapshot.
  List<ShgHealth> _shgs = [];
  bool _hasMore = false;
  bool _loadingMore = false;

  Future<PagedResult<ShgHealth>> _loadFirstPage() async {
    final page = await _repo.fetchShgList();
    _shgs = page.items;
    _hasMore = page.hasMore;
    return page;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _shgs.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _repo.fetchShgList(afterName: _shgs.last.name);
      setState(() {
        _shgs = [..._shgs, ...page.items];
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.analyticsShgListLoadMoreError)));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.analyticsShgListTitle),
      body: AppAsyncBuilder<PagedResult<ShgHealth>>(
        key: _key,
        future: _loadFirstPage,
        builder: (context, page) {
          if (_shgs.isEmpty) {
            return AppEmptyState(icon: Icons.apartment_rounded, message: l10n.analyticsShgListEmptyState);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _shgs.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _shgs.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: _loadingMore
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : TextButton(onPressed: _loadMore, child: Text(l10n.actionLoadMore)),
                  ),
                );
              }
              final g = _shgs[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  onTap: () => context.go(Paths.analyticsShgDetail(g.id)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(14, weight: FontWeight.w700)),
                              Text(l10n.analyticsShgListVillageMemberCount(g.village, g.memberCount), style: AppTheme.sans(12, color: Neutral.c500)),
                            ],
                          ),
                        ),
                        if (g.grade != null) AppBadge(text: g.grade!, tone: _gradeTone[g.grade] ?? BadgeTone.neutral),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: AppProgressBar(
                            value: g.healthScore,
                            tone: g.healthScore > 80 ? ProgressTone.brand : g.healthScore > 60 ? ProgressTone.gold : ProgressTone.danger,
                            // Was purely decorative to a screen reader — the
                            // only other on-row info is a letter grade
                            // badge, not the numeric score this bar
                            // visualizes.
                            semanticLabel: '${l10n.analyticsShgDetailHealthScore}: ${g.healthScore.toStringAsFixed(0)}%',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${g.healthScore.toStringAsFixed(0)}%', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                      ]),
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
