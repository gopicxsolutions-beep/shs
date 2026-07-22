/// Compile-time config, supplied via `--dart-define-from-file=.env.json`.
/// Only the public URL and anon key belong here — never the service-role key
/// or DB connection string, which must stay server-side only.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// A Sentry DSN is a public, write-only identifier (not a secret — it's
  /// safe to ship in a client build) but is still left unset unless supplied,
  /// same as the Supabase keys above: an empty value means "crash reporting
  /// disabled," so a plain `flutter run` with no `.env.json` still works
  /// exactly as before this was wired (see main.dart).
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');
}
