import 'package:supabase_flutter/supabase_flutter.dart';

/// Accessor for the shared Supabase client, plus whether the app was given
/// real credentials at build time (`--dart-define-from-file=.env.json`).
///
/// When unconfigured, [AppState] and the auth/onboarding pages fall back to
/// a local-only demo mode so the UI remains explorable without a backend —
/// see the branches on `isConfigured` in `lib/state/app_state.dart`.
class SupabaseService {
  SupabaseService._();
  static final instance = SupabaseService._();

  static bool isConfigured = false;

  SupabaseClient get client => Supabase.instance.client;
}
