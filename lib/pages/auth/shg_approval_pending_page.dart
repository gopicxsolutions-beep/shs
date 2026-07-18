import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/shg_join_request.dart';
import '../../repositories/shg_join_request_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

/// Shown to a member whose SHG join request hasn't been decided yet — see
/// `AppState.needsShgApproval` and the router redirect that gates on it.
class ShgApprovalPendingPage extends StatefulWidget {
  const ShgApprovalPendingPage({super.key});
  @override
  State<ShgApprovalPendingPage> createState() => _ShgApprovalPendingPageState();
}

class _ShgApprovalPendingPageState extends State<ShgApprovalPendingPage> {
  final _repo = ShgJoinRequestRepository();
  final GlobalKey<AppAsyncBuilderState<ShgJoinRequest?>> _key = GlobalKey();
  bool _checking = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    final appState = context.read<AppState>();
    try {
      await appState.refreshProfile();
      await _key.currentState?.reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not check status. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberId = context.watch<AppState>().profile?.id;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Neutral.c50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: AppAsyncBuilder<ShgJoinRequest?>(
            key: _key,
            future: () => _repo.fetchMine(memberId),
            builder: (context, request) {
              final rejected = request?.status == 'rejected';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 64, height: 64,
                    margin: const EdgeInsets.symmetric(horizontal: 100),
                    decoration: BoxDecoration(
                      color: rejected ? Accent.red50 : Gold.c50,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(rejected ? Icons.cancel_rounded : Icons.hourglass_top_rounded, color: rejected ? Accent.red600 : Gold.c600, size: 30),
                  ),
                  const SizedBox(height: 20),
                  Text(rejected ? l10n.shgApprovalRejectedTitle : l10n.shgApprovalWaitingTitle, textAlign: TextAlign.center, style: AppTheme.display(20)),
                  const SizedBox(height: 8),
                  Text(
                    rejected ? l10n.shgApprovalRejectedMessage : l10n.shgApprovalWaitingMessage,
                    textAlign: TextAlign.center,
                    style: AppTheme.sans(13, color: Neutral.c500),
                  ),
                  const SizedBox(height: 20),
                  if (request != null)
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.profileSHG, style: AppTheme.sans(11, weight: FontWeight.w700, color: Neutral.c500)),
                          const SizedBox(height: 2),
                          Text(request.shgName ?? l10n.unknownShg, style: AppTheme.sans(15, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (rejected)
                    AppButton(label: l10n.chooseDifferentShg, fullWidth: true, size: ButtonSize.lg, onPressed: () => context.go(Paths.profileSetup))
                  else
                    AppButton(label: _checking ? l10n.checkingStatus : l10n.actionCheckStatus, fullWidth: true, size: ButtonSize.lg, onPressed: _checking ? null : _checkStatus),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () async {
                      try {
                        await context.read<AppState>().signOut();
                      } catch (_) {
                        // Fall through to navigate regardless — local session
                        // state is cleared even if the remote sign-out call fails.
                      }
                      if (context.mounted) context.go(Paths.splash);
                    },
                    child: Text(l10n.actionSignOut, style: AppTheme.sans(13, color: Neutral.c500)),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
