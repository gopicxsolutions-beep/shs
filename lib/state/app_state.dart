import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, Session;
import '../models/profile.dart';
import '../models/types.dart';
import '../services/auth_service.dart';
import '../services/profile_repository.dart';
import '../services/supabase_service.dart';

/// App-wide session & profile state.
///
/// Two modes:
///  * **Configured** ([SupabaseService.isConfigured]): auth/profile are
///    backed by a real Supabase session + the `profiles` table.
///  * **Unconfigured** (no `.env.json` supplied at build time): falls back
///    to the original local-only demo mode — a SharedPreferences flag
///    stands in for "onboarding complete" and the role picker just flips
///    [defaultUser]'s role, so the 5 dashboards stay explorable without a
///    backend (matches the previous `restore()`/`setRole()` behavior).
class AppState extends ChangeNotifier {
  AppState({AuthService? authService, ProfileRepository? profileRepository})
      : _authService = authService ?? AuthService(),
        _profileRepository = profileRepository ?? ProfileRepository();

  final AuthService _authService;
  final ProfileRepository _profileRepository;
  StreamSubscription<AuthState>? _authSub;

  Language language = Language.en;

  Session? _session;
  Profile? _profile;
  ShgSearchResult? _pendingShg;

  bool _legacyOnboarded = false;
  Role _legacyRole = defaultUser.role;

  static const _roleKey = 'shg_role';
  static const _onboardedKey = 'shg_authenticated';
  static const _langKey = 'shg_language';

  /// A Supabase session exists (phone OTP verified), or — unconfigured —
  /// the legacy local onboarding flag is set.
  bool get hasSession => SupabaseService.isConfigured ? _session != null : _legacyOnboarded;

  /// A `profiles` row exists for the current session (profile setup done),
  /// or — unconfigured — the legacy local onboarding flag is set.
  bool get hasProfile => SupabaseService.isConfigured ? _profile != null : _legacyOnboarded;

  bool get isAuthenticated => hasSession && hasProfile;

  Profile? get profile => _profile;
  ShgSearchResult? get pendingShg => _pendingShg;

  AppUser get user {
    if (SupabaseService.isConfigured) {
      if (_profile == null) return defaultUser;
      final role = Role.values.where((r) => r.name == _profile!.role).firstOrNull ?? Role.member;
      return AppUser(
        name: _profile!.name,
        mobile: _profile!.mobile ?? defaultUser.mobile,
        role: role,
        shgName: _pendingShg?.name ?? defaultUser.shgName,
        village: _profile!.village ?? defaultUser.village,
      );
    }
    return defaultUser.copyWith(role: _legacyRole);
  }

  /// Call once at app start (replaces the old `restore()`).
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final langName = prefs.getString(_langKey);
    if (langName != null) {
      final match = Language.values.where((l) => l.name == langName);
      if (match.isNotEmpty) language = match.first;
    }

    if (!SupabaseService.isConfigured) {
      final roleName = prefs.getString(_roleKey);
      if (roleName != null) {
        final match = Role.values.where((r) => r.name == roleName);
        if (match.isNotEmpty) _legacyRole = match.first;
      }
      _legacyOnboarded = prefs.getBool(_onboardedKey) ?? false;
      notifyListeners();
      return;
    }

    _session = _authService.currentSession;
    if (_session != null) await _loadProfile();
    _authSub = _authService.onAuthStateChange.listen((state) async {
      _session = state.session;
      if (_session == null) {
        _profile = null;
      } else {
        await _loadProfile();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    try {
      _profile = await _profileRepository.fetchMyProfile();
    } catch (_) {
      _profile = null;
    }
  }

  /// Re-fetches the profile row — call right after OTP verification, since
  /// a fresh session may not have a `profiles` row yet.
  Future<void> refreshProfile() async {
    if (!SupabaseService.isConfigured) return;
    await _loadProfile();
    notifyListeners();
  }

  void setPendingShg(ShgSearchResult shg) {
    _pendingShg = shg;
    notifyListeners();
  }

  Future<void> completeProfileSetup({
    required String name,
    required String village,
    String? mandal,
    String? district,
  }) async {
    if (!SupabaseService.isConfigured) {
      _legacyOnboarded = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardedKey, true);
      notifyListeners();
      return;
    }
    _profile = await _profileRepository.upsertMyProfile(
      name: name,
      mobile: _session?.user.phone,
      role: 'member',
      shgId: _pendingShg?.id,
      village: village,
    );
    notifyListeners();
  }

  Future<void> setRole(Role role) async {
    if (SupabaseService.isConfigured) {
      if (_profile == null) return;
      await _profileRepository.updateRole(role.name);
      _profile = _profile!.copyWith(role: role.name);
      notifyListeners();
      return;
    }
    _legacyRole = role;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.name);
  }

  Future<void> setLanguage(Language lang) async {
    language = lang;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, lang.name);
  }

  Future<void> signOut() async {
    if (SupabaseService.isConfigured) {
      await _authService.signOut();
      _profile = null;
      _pendingShg = null;
    } else {
      _legacyOnboarded = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardedKey, false);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
