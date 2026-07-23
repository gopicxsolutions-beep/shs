import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/shg_join_request.dart';
import '../../repositories/shg_join_request_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

/// Leader-only screen: approve or reject members requesting to join their
/// SHG (spec: "Step 2: SHG Mapping — Member → Select SHG → Approval by
/// Leader").
class ShgJoinRequestsPage extends StatefulWidget {
  const ShgJoinRequestsPage({super.key});
  @override
  State<ShgJoinRequestsPage> createState() => _ShgJoinRequestsPageState();
}

class _ShgJoinRequestsPageState extends State<ShgJoinRequestsPage> {
  final _repo = ShgJoinRequestRepository();
  final GlobalKey<AppAsyncBuilderState<List<ShgJoinRequest>>> _key = GlobalKey();
  String? _deciding;

  Future<void> _decide(ShgJoinRequest request, bool approve) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _deciding = request.id);
    try {
      await _repo.decide(request.id, approve);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? (approve ? l10n.shgJoinRequestsApproved : l10n.shgJoinRequestsRejected) : l10n.shgJoinRequestsDemoMode),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.shgJoinRequestsProcessError)));
      }
    } finally {
      if (mounted) setState(() => _deciding = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shgId = context.watch<AppState>().profile?.shgId;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.shgJoinRequestsTitle),
      body: AppAsyncBuilder<List<ShgJoinRequest>>(
        key: _key,
        future: () => _repo.fetchPendingForShg(shgId),
        builder: (context, requests) {
          if (requests.isEmpty) {
            return AppEmptyState(icon: Icons.person_add_alt_1_rounded, message: l10n.shgJoinRequestsEmpty);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final r = requests[i];
              final busy = _deciding == r.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.memberName ?? l10n.shgJoinRequestsMemberFallback, style: AppTheme.sans(14, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(l10n.shgJoinRequestsRequestedOn(DateFormat('dd MMM yyyy').format(r.requestedAt)), style: AppTheme.sans(11, color: Neutral.c500)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: AppButton(label: l10n.shgJoinRequestsReject, variant: ButtonVariant.outline, fullWidth: true, onPressed: busy ? null : () => _decide(r, false))),
                        const SizedBox(width: 8),
                        Expanded(child: AppButton(label: busy ? l10n.shgJoinRequestsWorking : l10n.shgJoinRequestsApprove, fullWidth: true, onPressed: busy ? null : () => _decide(r, true))),
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
