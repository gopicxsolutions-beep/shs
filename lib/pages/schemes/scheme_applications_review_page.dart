import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/scheme.dart';
import '../../repositories/scheme_repository.dart' show SchemeApplicationAlreadyDecidedException, SchemeRepository;
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/avatar.dart';

/// Staff-only review queue for `scheme_applications` — see
/// SchemeRepository.fetchPendingApplications's doc comment for why this
/// page exists: the app could accept a scheme application but never let
/// anyone actually approve or reject it.
class SchemeApplicationsReviewPage extends StatefulWidget {
  const SchemeApplicationsReviewPage({super.key});
  @override
  State<SchemeApplicationsReviewPage> createState() => _SchemeApplicationsReviewPageState();
}

class _SchemeApplicationsReviewPageState extends State<SchemeApplicationsReviewPage> {
  final _repo = SchemeRepository();
  final _key = GlobalKey<AppAsyncBuilderState<List<SchemeApplicationReview>>>();
  final _deciding = <String>{};

  Future<void> _decide(SchemeApplicationReview app, bool approve) async {
    if (_deciding.contains(app.applicationId)) return;
    setState(() => _deciding.add(app.applicationId));
    try {
      await _repo.decideApplication(app.applicationId, approve: approve);
      _key.currentState?.reload();
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? (approve ? l10n.schemeApplicationsReviewApproved : l10n.schemeApplicationsReviewRejected) : l10n.profileUpdateDemoMode),
        ));
      }
    } on SchemeApplicationAlreadyDecidedException {
      // Another staff account already decided this application since the
      // shared review queue was loaded — reload so the now-stale row drops
      // out instead of sitting there looking actionable.
      _key.currentState?.reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.schemeApplicationsReviewAlreadyDecided)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.schemeApplicationsReviewSaveError)));
      }
    } finally {
      if (mounted) setState(() => _deciding.remove(app.applicationId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: PageHeader(title: l10n.schemeApplicationsReviewTitle),
      body: AppAsyncBuilder<List<SchemeApplicationReview>>(
        key: _key,
        future: _repo.fetchPendingApplications,
        builder: (context, apps) {
          if (apps.isEmpty) {
            return AppEmptyState(icon: Icons.fact_check_rounded, message: l10n.schemeApplicationsReviewEmptyState);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            itemBuilder: (context, i) {
              final app = apps[i];
              final deciding = _deciding.contains(app.applicationId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        AppAvatar(name: app.memberName, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(app.memberName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(14, weight: FontWeight.w700)),
                              Text(app.schemeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500)),
                            ],
                          ),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      Text(l10n.schemeApplicationsReviewAppliedOn(DateFormat('dd MMM yyyy').format(app.appliedOn)), style: AppTheme.sans(11, color: Neutral.c400)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: deciding ? null : () => _decide(app, false),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Accent.red100),
                              foregroundColor: Accent.red600,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(l10n.schemeApplicationsReviewReject),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: deciding ? null : () => _decide(app, true),
                            style: FilledButton.styleFrom(backgroundColor: Brand.c600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                            child: Text(deciding ? l10n.schemeApplicationsReviewSaving : l10n.schemeApplicationsReviewApprove),
                          ),
                        ),
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
