import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/app_state.dart';
import '../../widgets/error_screen.dart';

/// Shown instead of Profile Setup when `AppState.hasProfile` is false NOT
/// because the server confirmed there's no `profiles` row, but because the
/// most recent attempt to check it timed out or the connection dropped —
/// see `AppState.profileLoadFailedNetwork`'s doc comment.
///
/// A returning, already-onboarded user who opens the app offline must land
/// here, not on the "create your profile" onboarding form — that would
/// look exactly like the app forgot their account (or worse, invite them
/// to accidentally re-submit onboarding data). The router's `redirect`
/// callback (`routes/router.dart`) re-evaluates automatically whenever
/// `AppState` calls `notifyListeners()` — which `refreshProfile()` below
/// always does, success or failure — so a successful retry hands off to
/// the normal redirect logic (onward to Role Select / SHG approval /
/// dashboard, whichever applies) with no navigation call needed here.
class ProfileLoadErrorPage extends StatefulWidget {
  const ProfileLoadErrorPage({super.key});
  @override
  State<ProfileLoadErrorPage> createState() => _ProfileLoadErrorPageState();
}

class _ProfileLoadErrorPageState extends State<ProfileLoadErrorPage> {
  bool _retrying = false;

  Future<void> _retry() async {
    setState(() => _retrying = true);
    // Never throws — AppState._loadProfile() catches its own errors so the
    // failure state (profileLoadFailedNetwork) can be read back afterward
    // via the rebuild that notifyListeners() triggers, instead of
    // surfacing here.
    await context.read<AppState>().refreshProfile();
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppErrorScreen(
      title: l10n?.profileLoadErrorTitle ?? "Couldn't load your profile",
      message: l10n?.asyncErrorNetwork ?? 'Check your internet connection and try again.',
      retryLabel: l10n?.actionRetry ?? 'Retry',
      // A no-op (not null) while a retry is already in flight — keeps the
      // button visible instead of AppErrorScreen omitting it entirely
      // (which only happens when `onRetry` is null), while still ignoring
      // extra taps mid-request.
      onRetry: _retrying ? () {} : _retry,
    );
  }
}
