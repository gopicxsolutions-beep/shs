import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, Session;
import '../models/profile.dart';
import '../models/types.dart';
import '../repositories/shg_join_request_repository.dart';
import '../repositories/shg_repository.dart';
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
  AppState({AuthService? authService, ProfileRepository? profileRepository, ShgJoinRequestRepository? joinRequestRepository, ShgRepository? shgRepository})
      : _authService = authService ?? AuthService(),
        _profileRepository = profileRepository ?? ProfileRepository(),
        _joinRequestRepository = joinRequestRepository ?? ShgJoinRequestRepository(),
        _shgRepository = shgRepository ?? ShgRepository();

  final AuthService _authService;
  final ProfileRepository _profileRepository;
  final ShgJoinRequestRepository _joinRequestRepository;
  final ShgRepository _shgRepository;
  StreamSubscription<AuthState>? _authSub;

  Language language = Language.en;

  Session? _session;
  Profile? _profile;
  ShgSearchResult? _pendingShg;
  // The real SHG name for `_profile!.shgId`, fetched once the profile loads
  // — `_pendingShg` only ever reflects the SHG picked during onboarding and
  // is never repopulated on later sessions, so `user.shgName` fell back to
  // `defaultUser.shgName` (a hardcoded demo placeholder) for every returning
  // approved member. See `user` getter below.
  String? _shgName;
  int _profileLoadGeneration = 0;

  // Live mode only — true from the moment a fresh profile is created until
  // Role Select completes. Without this, `hasProfile` (just `_profile !=
  // null`) flips true the instant completeProfileSetup() runs, and the
  // router's "fully onboarded, leave auth flow" branch fires before Role
  // Select ever renders — the same bug already found and fixed for demo
  // mode (see the two-flag split below), but never fixed for live mode
  // since real phone OTP can't complete in this environment and this path
  // was never actually exercised. See docs/DEVELOPMENT_PROGRESS.md.
  //
  // This field's in-memory default (false) is indistinguishable from
  // "already completed", so a page reload between completeProfileSetup()
  // and setRole() used to permanently strand the user (router sees
  // hasProfile=true + needsRoleSelection=false + needsShgApproval=true and
  // locks them on ShgApprovalPendingPage with no request behind it, and no
  // route back to Role Select). `_loadProfile()` now restores this from a
  // SharedPreferences flag written by `_persistRoleSelectionPending()`
  // instead of relying purely on this in-memory default.
  bool _needsRoleSelection = false;

  // Demo mode mirrors the real two-step gate (session, then profile) with
  // two independent flags — collapsing them into one previously caused
  // profile setup to instantly satisfy both `hasSession` and `hasProfile`,
  // which skipped Role Select entirely (router saw onAuthFlow + fully
  // onboarded and bounced straight to the dashboard). Found via live UI
  // testing, not by analyze or DB tests — see docs/DEVELOPMENT_PROGRESS.md.
  bool _legacySessionStarted = false;
  bool _legacyOnboarded = false;
  Role _legacyRole = defaultUser.role;

  static const _roleKey = 'shg_role';
  static const _sessionKey = 'shg_session_started';
  static const _onboardedKey = 'shg_authenticated';
  static const _langKey = 'shg_language';

  /// A Supabase session exists (phone OTP verified), or — unconfigured —
  /// profile setup has been completed.
  bool get hasSession => SupabaseService.isConfigured ? _session != null : _legacySessionStarted;

  /// A `profiles` row exists for the current session (profile setup done),
  /// or — unconfigured — role selection has been completed.
  bool get hasProfile => SupabaseService.isConfigured ? _profile != null : _legacyOnboarded;

  bool get isAuthenticated => hasSession && hasProfile;

  /// Live mode only — a fresh profile exists but Role Select hasn't run
  /// yet this session.
  bool get needsRoleSelection => SupabaseService.isConfigured && _needsRoleSelection;

  /// Live mode only — a member's SHG join request hasn't been approved
  /// yet (`profiles.shg_id` is still null). Scoped to the `member` role
  /// since the spec's "Select SHG → Approval by Leader" workflow is about
  /// a rank-and-file member joining, not the role-preview personas
  /// (leader/crp/clf/admin) this app's Role Select otherwise offers.
  bool get needsShgApproval => SupabaseService.isConfigured && _profile != null && _profile!.role == 'member' && _profile!.shgId == null;

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
        shgName: _shgName ?? _pendingShg?.name ?? defaultUser.shgName,
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
      _legacySessionStarted = prefs.getBool(_sessionKey) ?? false;
      _legacyOnboarded = prefs.getBool(_onboardedKey) ?? false;
      notifyListeners();
      return;
    }

    _session = _authService.currentSession;
    if (_session != null) await _loadProfile();
    _authSub = _authService.onAuthStateChange.listen((state) async {
      _session = state.session;
      if (_session == null) {
        _profileLoadGeneration++;
        _profile = null;
      } else {
        await _loadProfile();
      }
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final generation = ++_profileLoadGeneration;
    try {
      final profile = await _profileRepository.fetchMyProfile();
      if (generation != _profileLoadGeneration) return;
      _profile = profile;
    } catch (_) {
      // Leave any previously-loaded profile in place — a transient fetch
      // failure shouldn't wipe a valid profile and bounce an already
      // onboarded user back into the onboarding flow.
      return;
    }
    final profile = _profile;
    if (profile == null) {
      _shgName = null;
      return;
    }
    try {
      // Non-critical enrichment: the real SHG name (see `_shgName` doc
      // above) and whether Role Select was already completed for this
      // profile in a previous session (see `_persistRoleSelectionPending`
      // doc above `_needsRoleSelection`). A failure here must not affect
      // the already-loaded `_profile`, so it's isolated in its own
      // try/catch rather than sharing the one above.
      final prefs = await SharedPreferences.getInstance();
      final shg = profile.shgId != null ? await _shgRepository.fetchShg(profile.shgId) : null;
      if (generation != _profileLoadGeneration) return;
      _needsRoleSelection = prefs.getBool(_roleSelectionPendingKey(profile.id)) ?? _needsRoleSelection;
      _shgName = shg?.name;
    } catch (_) {
      // Best-effort enrichment only — leave existing values in place.
    }
  }

  String _roleSelectionPendingKey(String profileId) => 'shg_role_selection_pending_$profileId';

  Future<void> _persistRoleSelectionPending(String profileId, bool pending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_roleSelectionPendingKey(profileId), pending);
    } catch (_) {
      // Best-effort — worst case this falls back to the pre-fix behavior
      // (role-selection-pending state not surviving a reload) rather than
      // throwing out of a routing-critical state transition.
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
      _legacySessionStarted = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, true);
      notifyListeners();
      return;
    }
    // shgId is deliberately NOT passed here — membership only takes effect
    // once the SHG's leader approves the join request below (see
    // needsShgApproval).
    _profile = await _profileRepository.upsertMyProfile(
      name: name,
      mobile: _session?.user.phone,
      role: 'member',
      village: village,
    );
    // Flip the routing flags and notify BEFORE the (separate) join-request
    // submit — if that submit fails, the router still sees a consistent
    // "profile created, needs role selection" state instead of a
    // half-finished one (hasProfile=true but needsRoleSelection=false,
    // which would silently skip Role Select on the next unrelated
    // notifyListeners()). The caller still sees the thrown exception.
    _needsRoleSelection = true;
    notifyListeners();
    await _persistRoleSelectionPending(_profile!.id, true);
    if (_pendingShg != null) {
      await _joinRequestRepository.submit(memberId: _profile!.id, shgId: _pendingShg!.id);
    }
  }

  Future<void> setRole(Role role) async {
    if (SupabaseService.isConfigured) {
      final profileId = _profile?.id;
      if (profileId == null) return;
      await _profileRepository.updateRole(role.name);
      // _profile may have been cleared by a concurrent sign-out while the
      // update above was in flight — only apply the result if it's still
      // the same profile, instead of force-unwrapping a possibly-null value.
      if (_profile?.id == profileId) {
        _profile = _profile!.copyWith(role: role.name);
        _needsRoleSelection = false;
        notifyListeners();
        await _persistRoleSelectionPending(profileId, false);
      }
      return;
    }
    _legacyRole = role;
    _legacyOnboarded = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, role.name);
    await prefs.setBool(_onboardedKey, true);
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
      _profileLoadGeneration++;
      _profile = null;
      _pendingShg = null;
      _shgName = null;
      _needsRoleSelection = false;
    } else {
      _legacySessionStarted = false;
      _legacyOnboarded = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, false);
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
