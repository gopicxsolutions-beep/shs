import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/shg_join_request.dart';
import '../../models/types.dart';
import '../../repositories/shg_join_request_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

/// Leader screen (own SHG) — also reachable by crp/clf/admin for a chosen
/// SHG via [shgId]/[shgName], mirroring `ShgMembersPage`'s override pattern.
/// `approve_shg_join_request` (RLS) already authorizes staff platform-wide
/// (`is_staff()`), but until this override existed there was no route that
/// ever passed a non-null shgId here — staff could legally decide any
/// request but had no way to ever reach one (spec: "Step 2: SHG Mapping —
/// Member → Select SHG → Approval by Leader", now also staff oversight).
class ShgJoinRequestsPage extends StatefulWidget {
  final String? shgId;
  final String? shgName;
  // Injectable so the approve-as-member/approve-as-leader role gating can be
  // widget-tested against canned request data instead of a real network call
  // — mirrors LoanApprovalPage's `repository` seam.
  final ShgJoinRequestRepository? repository;
  const ShgJoinRequestsPage({super.key, this.shgId, this.shgName, this.repository});
  @override
  State<ShgJoinRequestsPage> createState() => _ShgJoinRequestsPageState();
}

// Mirrors router.dart's own `is_staff()`-equivalent role set — kept as a
// local const here (that one is private to router.dart) rather than a new
// shared constant just for this one page.
const _staffRoles = {Role.crp, Role.clf, Role.admin};

class _ShgJoinRequestsPageState extends State<ShgJoinRequestsPage> {
  late final _repo = widget.repository ?? ShgJoinRequestRepository();
  final GlobalKey<AppAsyncBuilderState<List<ShgJoinRequest>>> _key = GlobalKey();
  String? _deciding;

  Future<void> _decide(ShgJoinRequest request, bool approve, {bool asLeader = false}) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _deciding = request.id);
    try {
      await _repo.decide(request.id, approve, asLeader: asLeader);
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
    final appState = context.watch<AppState>();
    final shgId = widget.shgId ?? appState.profile?.shgId;
    // Approve-as-leader is staff-only (see migration 0116's own RPC-level
    // enforcement) — a peer leader reviewing her own SHG's queue never sees
    // this option, so the client never dangles a control the backend would
    // reject.
    final canApproveAsLeader = _staffRoles.contains(appState.user.role);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.shgJoinRequestsTitle, subtitle: widget.shgName),
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
                      if (r.memberMobile != null) ...[
                        const SizedBox(height: 2),
                        // Lets a leader distinguish two same-named requesters
                        // or sanity-check identity before approving — the
                        // name alone (migration 0045's fix for this being
                        // silently unavailable at all) still isn't enough on
                        // its own for that kind of decision.
                        Text(r.memberMobile!, style: AppTheme.sans(12, color: Neutral.c600)),
                      ],
                      const SizedBox(height: 2),
                      Text(l10n.shgJoinRequestsRequestedOn(DateFormat('dd MMM yyyy').format(r.requestedAt)), style: AppTheme.sans(11, color: Neutral.c500)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: AppButton(label: l10n.shgJoinRequestsReject, variant: ButtonVariant.outline, fullWidth: true, onPressed: busy ? null : () => _decide(r, false))),
                        const SizedBox(width: 8),
                        Expanded(child: AppButton(label: busy ? l10n.shgJoinRequestsWorking : l10n.shgJoinRequestsApprove, fullWidth: true, onPressed: busy ? null : () => _decide(r, true))),
                      ]),
                      if (canApproveAsLeader) ...[
                        const SizedBox(height: 8),
                        AppButton(
                          label: l10n.shgJoinRequestsApproveAsLeader,
                          variant: ButtonVariant.outline,
                          fullWidth: true,
                          onPressed: busy ? null : () => _decide(r, true, asLeader: true),
                        ),
                      ],
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
