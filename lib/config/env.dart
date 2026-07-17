/// Compile-time config, supplied via `--dart-define-from-file=.env.json`.
/// Only the public URL and anon key belong here — never the service-role key
/// or DB connection string, which must stay server-side only.
class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
