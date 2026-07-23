import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState, Session;
import '../models/profile.dart';
import '../models/types.dart';
import '../repositories/shg_join_request_repository.dart';
import '../repositories/shg_repository.dart';
import '../services/auth_service.dart';
import '../services/profile_repository.dart';
import '../services/supabase_service.dart';
import '../widgets/async_state.dart' show isNetworkError;

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

  // Set by `_loadProfile()` when its most recent attempt failed because of
  // a network/connectivity problem specifically (not a confirmed "no such
  // row" response) while no profile had ever been successfully loaded yet.
  // See `profileLoadFailedNetwork` below for why this matters.
  bool _profileLoadFailedNetwork = false;

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
  String? _legacyName;
  String? _legacyVillage;

  // Captured by the router's `redirect` when it bounces an unauthenticated
  // user away from a genuine `/app/**` deep link, so `OtpPage` can send them
  // back to it after a successful sign-in instead of always landing on the
  // dashboard. See `capturePendingDeepLink`/`consumePendingDeepLink` below.
  //
  // In-memory only, deliberately not persisted — a fresh `AppState` on app
  // restart starts with this null, which is correct: re-opening the same
  // bookmark re-captures it from scratch via the same redirect path, and a
  // half-remembered target surviving a restart with no way to have been
  // consumed would be a stale-state risk for no real benefit.
  String? _pendingDeepLink;

  static const _roleKey = 'shg_role';
  static const _sessionKey = 'shg_session_started';
  static const _onboardedKey = 'shg_authenticated';
  static const _langKey = 'shg_language';
  static const _nameKey = 'shg_demo_name';
  static const _villageKey = 'shg_demo_village';

  /// A Supabase session exists (phone OTP verified), or — unconfigured —
  /// profile setup has been completed.
  bool get hasSession => SupabaseService.isConfigured ? _session != null : _legacySessionStarted;

  /// A `profiles` row exists for the current session (profile setup done),
  /// or — unconfigured — role selection has been completed.
  bool get hasProfile => SupabaseService.isConfigured ? _profile != null : _legacyOnboarded;

  /// True when the most recent attempt to fetch the current session's
  /// `profiles` row failed because of a network/connectivity problem
  /// (dropped connection, DNS failure, or the client-side request timeout —
  /// see `isNetworkError` in `widgets/async_state.dart`) rather than a
  /// confirmed "no such row" response from the server, AND no profile has
  /// ever been successfully loaded this session (`_profile` is still null).
  ///
  /// Without this distinction, a returning already-onboarded user who opens
  /// the app offline looks identical — to the router — to a genuinely
  /// brand-new user: both have `hasSession && !hasProfile`. The router's
  /// `redirect` callback checks this flag to route the former to a
  /// retry-capable "couldn't load your profile" screen instead of silently
  /// sending them through Profile Setup, which looks exactly like the app
  /// forgot their account (or worse, invites them to accidentally
  /// re-onboard). See docs/DEVELOPMENT_PROGRESS.md round 67, which
  /// diagnosed this and deferred the fix to a dedicated round.
  bool get profileLoadFailedNetwork => SupabaseService.isConfigured && _profile == null && _profileLoadFailedNetwork;

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

  /// Whether `Paths.roleSelect` is a legitimate destination while
  /// [hasProfile] is still false — used by the router's redirect to decide
  /// what counts as "still onboarding" before a `profiles` row exists.
  ///
  /// True only in demo/unconfigured mode: unlike live mode's 3-stage
  /// session → profile → role pipeline, demo mode's two legacy flags double
  /// up stages (`hasSession` == "profile setup done", `hasProfile` == "Role
  /// Select done" — see the two-flag doc comment above), so `!hasProfile`
  /// there genuinely means "Role Select is the very next, and only
  /// reachable, step" — the mechanism that lets demo mode ever reach Role
  /// Select at all, since [needsRoleSelection] is unconditionally false in
  /// demo mode.
  ///
  /// In live mode, `!hasProfile` instead means no `profiles` row exists yet
  /// — Role Select has nothing to write to (`setRole()` silently no-ops
  /// when `_profile` is null), so treating it as reachable there let a
  /// direct URL visit to `/role-select` right after OTP verification (before
  /// `profileSetup` ever ran) silently swallow a role tap: `setRole()`
  /// no-ops without throwing, `RoleSelectPage` sees no exception and
  /// navigates to the dashboard, and the router's very next redirect
  /// evaluation immediately bounces it back to `profileSetup` since
  /// `hasProfile` is still false — a confusing dead-end with zero
  /// explanation shown to the user.
  bool get roleSelectReachableWithoutProfile => !SupabaseService.isConfigured;

  Profile? get profile => _profile;
  ShgSearchResult? get pendingShg => _pendingShg;

  AppUser get user {
    if (SupabaseService.isConfigured) {
      if (_profile == null) return defaultUser;
      // Root-cause note (live-testing report: a persisted "leader" account's
      // Profile page correctly showed "SHG Leader / President" but a
      // role-gated "+" button elsewhere in the app stayed hidden): this line
      // is the ONLY place `_profile!.role` (the raw `profiles.role` string)
      // gets turned into a `Role`, and every reader of a role anywhere in
      // the app — the Profile page's badge (`roleInfoFor(user.role)`) and
      // every `appState.user.role != Role.member` gate alike (this file's
      // `_FirstOrNull` fallback below) — goes through this same `user`
      // getter on this same shared `AppState` singleton. That makes it
      // structurally impossible for two call sites to disagree about a
      // single account's role at a single point in time: either this line
      // matched the DB string and every reader sees the resolved `Role`, or
      // it silently fell back to `Role.member` and every reader — Profile
      // page included — would show "SHG Member", not a correct badge next
      // to a wrongly-hidden button. See `test/pages/shg_documents_page_test
      // .dart`'s "live mode" group, which proves both directions with a
      // widget test (including one pumping the Profile page and
      // ShgDocumentsPage off the identical `AppState` instance). A report
      // that genuinely showed the two disagreeing therefore points at
      // something outside this getter for that one session (e.g. a stale
      // client build, or the observation being made at two different
      // points in time around a role change) rather than a bug reachable
      // from this code path — confirm via the account's actual live
      // `profiles.role` value if it recurs, since no client-side fix
      // reproduces it.
      final role = Role.values.where((r) => r.name == _profile!.role).firstOrNull ?? Role.member;
      return AppUser(
        name: _profile!.name,
        mobile: _profile!.mobile ?? defaultUser.mobile,
        role: role,
        // No demo-name fallback here: a live staff account genuinely has no
        // SHG (see profile_setup_page.dart), and showing "Sri Durga Mahila
        // SHG" — the hardcoded demo persona's SHG — under a real admin's
        // name would misrepresent live data as if it were theirs.
        shgName: _shgName ?? _pendingShg?.name ?? '',
        village: _profile!.village ?? defaultUser.village,
      );
    }
    return defaultUser.copyWith(role: _legacyRole, name: _legacyName, village: _legacyVillage);
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
      _legacyName = prefs.getString(_nameKey);
      _legacyVillage = prefs.getString(_villageKey);
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
        _profileLoadFailedNetwork = false;
      } else if (state.event != AuthChangeEvent.tokenRefreshed) {
        // GoTrue's auto-refresh timer fires this listener roughly hourly
        // (see gotrue's `_autoRefreshTokenTick`) purely to rotate the JWT —
        // the `profiles`/`shgs` rows behind it never change as a result, so
        // re-running `_loadProfile()` (two network round-trips) on every
        // tick was pure waste for as long as the app stayed open. Every
        // other event (`initialSession`, `signedIn`, `userUpdated`, ...)
        // still refetches, since those genuinely can correspond to a new or
        // changed profile.
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
      // A successful fetch — even one that confirms `profile == null` (a
      // genuinely new user, no `profiles` row yet) — means we definitively
      // know the answer, so any earlier network-failure flag no longer
      // applies.
      _profile = profile;
      _profileLoadFailedNetwork = false;
    } catch (error) {
      if (generation != _profileLoadGeneration) return;
      // Leave any previously-loaded profile in place — a transient fetch
      // failure shouldn't wipe a valid profile and bounce an already
      // onboarded user back into the onboarding flow. Separately, remember
      // whether THIS failure was network-related and no profile has ever
      // been loaded (see `profileLoadFailedNetwork`'s doc comment) — that's
      // the "we couldn't check" case the router must route differently
      // from a confirmed "no profile" response. A network error after a
      // profile was already loaded doesn't set this — `hasProfile` is
      // already true then, so the router never reads this flag anyway.
      _profileLoadFailedNetwork = _profile == null && isNetworkError(error);
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

  /// The most recently captured deep-link target awaiting replay after
  /// sign-in, if any. See `capturePendingDeepLink`/`consumePendingDeepLink`.
  String? get pendingDeepLink => _pendingDeepLink;

  /// Records `location` as the destination to return to once the user has
  /// signed in. Called only by the router's `redirect`, for an
  /// unauthenticated visit to a genuine `/app/**` route.
  ///
  /// Deliberately does NOT call `notifyListeners()`: this runs synchronously
  /// from inside GoRouter's own `redirect` callback (via `refreshListenable`
  /// this same `AppState`), so notifying listeners here would re-enter
  /// routing mid-decision instead of just recording state for `OtpPage` to
  /// read back later.
  void capturePendingDeepLink(String location) => _pendingDeepLink = location;

  /// Returns the most recently captured deep link, if any, and clears it —
  /// single-use, so it can never leak into a later, unrelated sign-in.
  String? consumePendingDeepLink() {
    final location = _pendingDeepLink;
    _pendingDeepLink = null;
    return location;
  }

  Future<void> completeProfileSetup({
    required String name,
    required String village,
    String? mandal,
    String? district,
  }) async {
    if (!SupabaseService.isConfigured) {
      _legacySessionStarted = true;
      // Demo mode has no real profile row to persist to, so without this
      // the name/village typed here were silently discarded and the app
      // kept showing the default "Lakshmi Devi" persona everywhere.
      if (name.isNotEmpty) _legacyName = name;
      if (village.isNotEmpty) _legacyVillage = village;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_sessionKey, true);
      if (_legacyName != null) await prefs.setString(_nameKey, _legacyName!);
      if (_legacyVillage != null) await prefs.setString(_villageKey, _legacyVillage!);
      notifyListeners();
      return;
    }
    // shgId is deliberately NOT passed here — membership only takes effect
    // once the SHG's leader approves the join request below (see
    // needsShgApproval).
    //
    // This method is also the "Choose a different SHG" retry path a
    // rejected member reaches from ShgApprovalPendingPage (profileSetup
    // stays reachable while needsShgApproval is true — see the router).
    // Only a genuinely NEW profile still needs Role Select: without this
    // `isNewProfile` guard, that retry unconditionally forced
    // `_needsRoleSelection` back to true below, sending an already
    // role-selected member back through Role Select a second time even
    // though they were only ever picking a new SHG — a confusing extra
    // step, and one that let them pick a different role (e.g. Leader) on
    // the redo, silently escaping the pending-approval workflow they were
    // already in the middle of.
    final isNewProfile = _profile == null;
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
    if (isNewProfile) _needsRoleSelection = true;
    notifyListeners();
    if (isNewProfile) await _persistRoleSelectionPending(_profile!.id, true);
    if (_pendingShg != null) {
      await _joinRequestRepository.submit(memberId: _profile!.id, shgId: _pendingShg!.id);
    }
  }

  /// Self-service role selection — always the CALLER's own profile. Staff
  /// roles (crp/clf/admin) must never be reachable here: this is the
  /// onboarding Role Select page, not an admin-driven change (that's
  /// `AdminRepository.updateUserRole`, gated to admin in the UI). The real
  /// boundary is server-side — `profiles_update_self_or_admin`'s `with
  /// check` (`supabase/migrations/0009_profiles_role_escalation_fix.sql`,
  /// deployed and live since round 23) already rejects a self-update that
  /// sets `role` to anything but the caller's current role or
  /// member/leader. This client-side guard is defense-in-depth on top of
  /// that: it fails fast with a clear error instead of surfacing a raw
  /// `PostgrestException` if this code path is ever reached with a
  /// disallowed role (e.g. a future UI change that re-adds a staff option
  /// to this page by mistake).
  Future<void> setRole(Role role) async {
    if (SupabaseService.isConfigured) {
      if (role == Role.crp || role == Role.clf || role == Role.admin) {
        throw StateError('Staff and admin roles can only be granted by an administrator.');
      }
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
      _profileLoadFailedNetwork = false;
      // A pending deep link belongs to whoever is about to sign in next —
      // without this, signing out and back in as a different account could
      // replay the previous account's captured destination.
      _pendingDeepLink = null;
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
