import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../widgets/error_screen.dart';

/// Shown instead of the dashboard when `AppState.accountDeactivated` is
/// true — an admin set `profiles.is_active = false` on this account
/// (migration 0083). Unlike [ProfileLoadErrorPage], retrying can't help
/// here (only an admin reactivating the account would), so the only action
/// offered is signing out — same signOut() + context.go(Paths.splash)
/// shape as ProfilePage's own Sign Out button.
class AccountDeactivatedPage extends StatelessWidget {
  const AccountDeactivatedPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppErrorScreen(
      title: l10n?.accountDeactivatedTitle ?? 'Account deactivated',
      message: l10n?.accountDeactivatedMessage ?? 'Your account has been deactivated. Contact your CRP or SHG federation admin if you believe this is a mistake.',
      retryLabel: l10n?.actionSignOut ?? 'Sign Out',
      onRetry: () async {
        try {
          await context.read<AppState>().signOut();
        } catch (_) {
          // fall through — still navigate to splash below
        }
        if (context.mounted) context.go(Paths.splash);
      },
    );
  }
}
