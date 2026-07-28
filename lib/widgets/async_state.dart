import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/gen/app_localizations.dart';
import '../routes/paths.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// True for a genuine dropped-connection/DNS/timeout failure (as opposed to
/// a permission or data error surfaced by Supabase itself).
///
/// [http.ClientException] is thrown by `package:http` (which every
/// Supabase sub-client — Postgrest, Auth, Storage, Functions — is built on)
/// for socket-level failures on both web and IO platforms: on IO it wraps
/// `dart:io`'s [SocketException] (unreachable on web, so checked this way
/// instead), and on web it wraps the browser's own fetch/XHR network error.
/// [TimeoutException] covers the client-side request timeout configured in
/// `main.dart`'s `TimeoutHttpClient`. Neither is specific to any one
/// repository call, so this check is safe to apply generically here.
bool isNetworkError(Object? error) => error is TimeoutException || error is http.ClientException;

/// True when a query failed because the session's access token is expired
/// or otherwise no longer valid — as opposed to a permission (RLS) or data
/// error. Before this, every repository-backed page's catch-all "Something
/// went wrong. Please try again." + Retry button treated this identically
/// to any other failure: tapping Retry resends the same stale token and
/// fails again in a loop, with no path back to signing in, until GoTrue's
/// own background refresh timer happens to fire (which it may miss for
/// hours after the app sits backgrounded — see `AppState`'s auth-listener
/// doc comment). PostgREST returns `PGRST301` ("JWT expired") for an
/// expired-but-well-formed token; a malformed/invalid one instead surfaces
/// as a [AuthException] from gotrue. Matched by `code`/type rather than by
/// parsing `message` text, which isn't a stable contract across versions.
bool isAuthExpiredError(Object? error) => (error is PostgrestException && error.code == 'PGRST301') || error is AuthException;

/// Wraps a [Future] with consistent loading / error+retry / data states.
/// Shared across every data-backed feature screen (Savings, Loans, ...) so
/// each repository-backed page doesn't hand-roll its own FutureBuilder.
class AppAsyncBuilder<T> extends StatefulWidget {
  final Future<T> Function() future;
  final Widget Function(BuildContext context, T data) builder;
  // Null falls back to the localized generic error message (see build()) —
  // can't be a localized string here since a widget's default parameter
  // value must be a compile-time constant.
  final String? errorMessage;
  const AppAsyncBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.errorMessage,
  });

  @override
  State<AppAsyncBuilder<T>> createState() => AppAsyncBuilderState<T>();
}

class AppAsyncBuilderState<T> extends State<AppAsyncBuilder<T>> {
  late Future<T> _future;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _future = widget.future();
  }

  Future<void> reload() {
    final next = widget.future();
    setState(() {
      _future = next;
    });
    return next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // A bare CircularProgressIndicator has no accessible name of its
          // own — TalkBack/VoiceOver announce nothing at all while this is
          // on screen, so a screen-reader user landing on almost any
          // data-driven page mid-load hears silence indistinguishable from
          // a frozen/broken app. `Semantics(label:, liveRegion: true)`
          // gives it an announced "Loading" and re-announces if the same
          // node is reused for a subsequent reload.
          final l10n = AppLocalizations.of(context);
          return Semantics(
            label: l10n?.commonLoading ?? 'Loading…',
            liveRegion: true,
            child: const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
          );
        }
        if (snapshot.hasError) {
          final isNetwork = isNetworkError(snapshot.error);
          final isAuthExpired = isAuthExpiredError(snapshot.error);
          // Nullable, not `!`: this widget backs almost every data-driven
          // screen in the app (Dashboard, Savings, Loans, Meetings, ...),
          // including older widget tests that pump a bare `MaterialApp`
          // with no localization delegates configured — fall back to
          // English rather than crash their build in that case; a real
          // app boot always has the delegates via MaterialApp.router.
          final l10n = AppLocalizations.of(context);
          final message = isAuthExpired
              ? (l10n?.asyncErrorSessionExpired ?? 'Your session has expired. Please sign in again.')
              : isNetwork
                  ? (l10n?.asyncErrorNetwork ?? 'Check your internet connection and try again.')
                  : (widget.errorMessage ?? l10n?.asyncErrorGeneric ?? 'Something went wrong. Please try again.');
          // Same reasoning as the loading state's Semantics above — a
          // screen-reader user not already focused on this region would
          // otherwise hear nothing at all when a load fails.
          return Semantics(
            liveRegion: true,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded, color: Accent.red500, size: 32),
                  const SizedBox(height: 12),
                  Text(message, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
                  const SizedBox(height: 12),
                  // A stale-token failure can't be fixed by resending the
                  // same request — Retry would just repeat the same 401 in
                  // a loop. Sign out (clearing the dead session) and send
                  // the user back to the auth flow instead, same signOut()
                  // + context.go() shape ProfilePage's own Sign Out button
                  // already uses.
                  isAuthExpired
                      ? TextButton(
                          // Was tappable indefinitely with no feedback — this
                          // is the token-expiry recovery path reached from
                          // nearly every data-driven page in the app (this
                          // widget backs almost all of them), so the same
                          // AppState.signOut() hang risk ProfilePage's Sign
                          // Out button now guards against was wired into a
                          // much more frequently hit path. signOut() itself
                          // now bounds the risky call with a timeout; this
                          // just stops a repeat tap from firing a second
                          // concurrent signOut() while the first is in flight.
                          onPressed: _signingOut
                              ? null
                              : () async {
                                  setState(() => _signingOut = true);
                                  try {
                                    await context.read<AppState>().signOut();
                                  } catch (_) {
                                    // fall through — still navigate to splash below
                                  }
                                  if (context.mounted) context.go(Paths.splash);
                                },
                          child: Text(_signingOut ? (l10n?.profileSigningOut ?? 'Signing out…') : (l10n?.actionSignInAgain ?? 'Sign In Again')),
                        )
                      : TextButton(onPressed: reload, child: Text(l10n?.actionRetry ?? 'Retry')),
                ]),
              ),
            ),
          );
        }
        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}

/// A simple centered empty-state block used inside list screens.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const AppEmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 32, color: Neutral.c300),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
      ]),
    );
  }
}
