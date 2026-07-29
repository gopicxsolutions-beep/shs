import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/admin.dart';
import '../../models/paged_result.dart';
import '../../repositories/admin_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

String _actionLabel(AppLocalizations l10n, String action) => switch (action) {
      'role_change' => l10n.adminAuditLogActionRoleChange,
      'shg_grade_change' => l10n.adminAuditLogActionShgGradeChange,
      'livelihood_staff_override' => l10n.adminAuditLogActionLivelihoodOverride,
      'loan_decision' => l10n.adminAuditLogActionLoanDecision,
      'deactivation' => l10n.adminAuditLogActionDeactivation,
      'shg_reassignment' => l10n.adminAuditLogActionShgReassignment,
      _ => action,
    };

// meta's shape is action-specific (see migration 0082's four trigger
// functions) — this renders the common "old -> new" shape each of them
// shares, falling back to a generic key: value join for anything else
// rather than showing nothing for a meta shape this page doesn't
// specifically recognize.
String _metaSummary(AppLocalizations l10n, Map<String, dynamic> meta) {
  // `is_active` is a raw boolean, unlike every other old->new pair here
  // (short human-readable enum strings) — rendered via the generic
  // `'${old} → ${new}'` join it printed the unlocalized Dart booleans
  // `true`/`false` verbatim on an otherwise fully hi/te-localized page.
  if (meta.containsKey('old_is_active')) {
    String label(dynamic v) => v == true ? l10n.adminAuditLogActiveValue : l10n.adminAuditLogInactiveValue;
    return '${label(meta['old_is_active'])} → ${label(meta['new_is_active'])}';
  }
  final pairs = <String>[];
  const knownPairs = [
    ('old_role', 'new_role'),
    ('old_grade', 'new_grade'),
    ('old_status', 'new_status'),
    ('old_revenue', 'new_revenue'),
    ('old_shg_id', 'new_shg_id'),
  ];
  for (final (oldKey, newKey) in knownPairs) {
    if (meta.containsKey(oldKey) && meta[oldKey] != meta[newKey]) {
      pairs.add('${meta[oldKey]} → ${meta[newKey]}');
    }
  }
  if (pairs.isNotEmpty) return pairs.join(' · ');
  // `loan_decision`'s meta shape (`decision`, `emi`) doesn't match any of
  // the old->new pairs above — every entry of this action type used to hit
  // this exact hardcoded-English fallback regardless of app language.
  if (meta.containsKey('decision')) return l10n.adminAuditLogDecisionLabel(meta['decision']);
  return meta.entries.map((e) => '${e.key}: ${e.value}').join(' · ');
}

/// Admin-only view of `public.audit_log` — see [AuditLogEntry]'s doc
/// comment for why this page exists: the triggers writing to this table
/// (migration 0082) previously had no reader at all.
class AdminAuditLogPage extends StatefulWidget {
  const AdminAuditLogPage({super.key});
  @override
  State<AdminAuditLogPage> createState() => _AdminAuditLogPageState();
}

class _AdminAuditLogPageState extends State<AdminAuditLogPage> {
  final _repo = AdminRepository();
  final GlobalKey<AppAsyncBuilderState<PagedResult<AuditLogEntry>>> _key = GlobalKey();

  List<AuditLogEntry> _entries = [];
  bool _hasMore = false;
  bool _loadingMore = false;

  Future<PagedResult<AuditLogEntry>> _loadFirstPage() async {
    final page = await _repo.fetchAuditLog();
    _entries = page.items;
    _hasMore = page.hasMore;
    return page;
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _entries.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final last = _entries.last;
      final page = await _repo.fetchAuditLog(afterCreatedAt: last.createdAt, afterId: last.id);
      setState(() {
        _entries = [..._entries, ...page.items];
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.adminAuditLogLoadMoreError)));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: PageHeader(title: l10n.adminAuditLogTitle),
      body: AppAsyncBuilder<PagedResult<AuditLogEntry>>(
        key: _key,
        future: _loadFirstPage,
        builder: (context, page) {
          if (_entries.isEmpty) {
            return AppEmptyState(icon: Icons.receipt_long_rounded, message: l10n.adminAuditLogEmpty);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _entries.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _entries.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: _loadingMore
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                        : TextButton(onPressed: _loadMore, child: Text(l10n.actionLoadMore)),
                  ),
                );
              }
              final e = _entries[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Flexible(child: Text(_actionLabel(l10n, e.action), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(13, weight: FontWeight.w700))),
                        const SizedBox(width: 8),
                        AppBadge(text: e.entity, tone: BadgeTone.neutral),
                      ]),
                      const SizedBox(height: 6),
                      Text(_metaSummary(l10n, e.meta), style: AppTheme.sans(12, color: Neutral.c600)),
                      const SizedBox(height: 6),
                      Text(
                        l10n.adminAuditLogByAt(e.actorName ?? l10n.adminAuditLogUnknownActor, DateFormat('dd MMM yyyy, hh:mm a').format(e.createdAt)),
                        style: AppTheme.sans(11, color: Neutral.c400),
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
