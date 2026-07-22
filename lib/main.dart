import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';
import 'l10n/gen/app_localizations.dart';
import 'models/types.dart';
import 'routes/router.dart';
import 'services/supabase_service.dart';
import 'services/timeout_http_client.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/error_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Widget-build errors get a friendly fallback instead of Flutter's
  // default gray/red screen. This hook is independent of the crash
  // reporting below — Sentry's own FlutterError.onError integration
  // (wired inside SentryFlutter.init) reports the same errors on its own;
  // this just controls what the user sees on screen.
  ErrorWidget.builder = (details) {
    FlutterError.presentError(details);
    return const AppErrorScreen(title: 'Something went wrong', message: 'This screen ran into a problem. Please go back and try again.');
  };

  if (Env.sentryDsn.isNotEmpty) {
    // Crash/error reporting — only active when a DSN is supplied via
    // --dart-define-from-file (see Env.sentryDsn's doc comment). Uncaught
    // errors, and widget-build errors via FlutterError.onError, are
    // reported automatically once initialized; no DSN means this block is
    // skipped entirely and _startApp runs through the plain
    // runZonedGuarded+debugPrint fallback below instead, same as before
    // crash reporting was wired up.
    await SentryFlutter.init((options) {
      options.dsn = Env.sentryDsn;
      // Crash/error visibility is the goal here, not performance
      // tracing — no APM budget to justify tracing overhead on this
      // app's rural/low-bandwidth connections.
      options.tracesSampleRate = 0.0;
    }, appRunner: _startApp);
  } else {
    runZonedGuarded(_startApp, (error, stack) {
      // No DSN configured (local dev, demo builds) — still guard against
      // an uncaught error taking down the whole app silently; just log it
      // instead of also reporting it remotely.
      debugPrint('Uncaught error: $error\n$stack');
    });
  }
}

Future<void> _startApp() async {
  if (Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty) {
    // Every Supabase sub-client (Postgrest, Auth, Storage, Functions) is
    // threaded through this one httpClient, so this single change bounds
    // every network call in the app — see TimeoutHttpClient's doc comment
    // for why this matters on this app's slow/unreliable rural connections.
    await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey, httpClient: TimeoutHttpClient());
    SupabaseService.isConfigured = true;
  }
  runApp(const ShgSaathiApp());
}

class ShgSaathiApp extends StatefulWidget {
  const ShgSaathiApp({super.key});

  @override
  State<ShgSaathiApp> createState() => _ShgSaathiAppState();
}

class _ShgSaathiAppState extends State<ShgSaathiApp> {
  final _appState = AppState();
  late final GoRouter _router;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(_appState);
    // A failure here (e.g. SharedPreferences unavailable) must still flip
    // `_ready` — otherwise the app is stuck on the splash spinner forever
    // with no way for the user to recover.
    _appState.init().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // No localization delegates are wired up on this bare pre-boot
      // MaterialApp (that only happens below, once `_router`/`_appState`
      // are ready), so a hardcoded English label is the only option here —
      // matches the AppLocalizations-unavailable fallback strings used
      // elsewhere (e.g. `async_state.dart`). Without this, TalkBack/VoiceOver
      // announce nothing at all during the very first thing every user sees
      // on every app launch, indistinguishable from a frozen/blank screen.
      return MaterialApp(
        home: Scaffold(body: Center(child: Semantics(label: 'Loading…', liveRegion: true, child: const CircularProgressIndicator()))),
      );
    }
    return ChangeNotifierProvider.value(
      value: _appState,
      child: AnimatedBuilder(
        animation: _appState,
        builder: (context, _) => MaterialApp.router(
          title: 'NavaSakhi',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.data,
          routerConfig: _router,
          locale: _localeFor(_appState.language),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }

  Locale _localeFor(Language language) {
    switch (language) {
      case Language.te:
        return const Locale('te');
      case Language.hi:
        return const Locale('hi');
      case Language.en:
        return const Locale('en');
    }
  }
}
