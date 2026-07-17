import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Thin wrapper around Supabase phone-OTP auth. Exceptions (typically
/// [AuthException] from supabase_flutter) propagate to callers, which are
/// expected to catch and surface a friendly message.
class AuthService {
  SupabaseClient get _client => SupabaseService.instance.client;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Sends a 6-digit OTP via SMS to [e164Phone] (e.g. `+919876543210`).
  /// Requires a phone provider (e.g. Twilio) configured on the Supabase
  /// project — see README for setup notes.
  Future<void> sendOtp(String e164Phone) {
    return _client.auth.signInWithOtp(phone: e164Phone);
  }

  /// Verifies [token] against [e164Phone] and, on success, establishes a
  /// session (picked up by [AppState] via [onAuthStateChange]).
  Future<AuthResponse> verifyOtp(String e164Phone, String token) {
    return _client.auth.verifyOTP(type: OtpType.sms, phone: e164Phone, token: token);
  }

  Future<void> signOut() => _client.auth.signOut();
}
