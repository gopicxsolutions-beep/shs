import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';
import 'l10n/gen/app_localizations.dart';
import 'models/types.dart';
import 'routes/router.dart';
import 'services/supabase_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/error_screen.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Widget-build errors get a friendly fallback instead of Flutter's
    // default gray/red screen — still logged to console either way.
    ErrorWidget.builder = (details) {
      FlutterError.presentError(details);
      return const AppErrorScreen(title: 'Something went wrong', message: 'This screen ran into a problem. Please go back and try again.');
    };

    if (Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
      SupabaseService.isConfigured = true;
    }
    runApp(const ShgSaathiApp());
  }, (error, stack) {
    // No crash-reporting service is wired up (would need an external
    // API key, e.g. Sentry/Crashlytics) — log so errors are at least
    // visible instead of silently vanishing in a detached zone.
    debugPrint('Uncaught error: $error\n$stack');
  });
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
    _appState.init().then((_) => setState(() => _ready = true));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    return ChangeNotifierProvider.value(
      value: _appState,
      child: AnimatedBuilder(
        animation: _appState,
        builder: (context, _) => MaterialApp.router(
          title: 'SHG Saathi',
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
