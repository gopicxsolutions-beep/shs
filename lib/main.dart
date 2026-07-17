import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';
import 'routes/router.dart';
import 'services/supabase_service.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.supabaseUrl.isNotEmpty && Env.supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseAnonKey);
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
    _appState.init().then((_) => setState(() => _ready = true));
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    return ChangeNotifierProvider.value(
      value: _appState,
      child: MaterialApp.router(
        title: 'SHG Saathi',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.data,
        routerConfig: _router,
      ),
    );
  }
}
