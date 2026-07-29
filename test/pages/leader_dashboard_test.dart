import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/models/profile.dart';
import 'package:shg_saathi/pages/dashboard/leader_dashboard.dart';
import 'package:shg_saathi/services/auth_service.dart';
import 'package:shg_saathi/services/profile_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

class _FixedProfileRepository extends ProfileRepository {
  _FixedProfileRepository(this._profile);
  final Profile? _profile;
  @override
  Future<Profile?> fetchMyProfile() async => _profile;
}

class _FakeAuthServiceWithSession extends AuthService {
  @override
  Session? get currentSession => Session(
        accessToken: 'token',
        tokenType: 'bearer',
        refreshToken: 'refresh',
        user: User(id: 'u1', appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: DateTime(2026).toIso8601String()),
      );

  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

/// Onboarding-redesign regression: before this fix, `LeaderDashboard` had no
/// `shgId == null` guard at all — a leader account left unlinked (the exact
/// state every self-registered Leader used to end up in — see AppState.
/// completeProfileSetup's doc comment) saw a fully-rendered but entirely
/// empty dashboard (₹0.0L everywhere, "no pending loans"), indistinguishable
/// from a genuinely brand-new, empty SHG.
void main() {
  setUp(() {
    SupabaseService.isConfigured = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => SupabaseService.isConfigured = false);

  Future<AppState> leaderAppState({required String? shgId}) async {
    final appState = AppState(
      profileRepository: _FixedProfileRepository(Profile(id: 'leader-1', name: 'QA Leader', role: 'leader', shgId: shgId)),
      authService: _FakeAuthServiceWithSession(),
    );
    await appState.init();
    return appState;
  }

  Future<void> boot(WidgetTester tester, AppState appState) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: const Scaffold(body: LeaderDashboard()),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a leader with a null shgId (broken/unlinked account) sees an explanatory message, not a fully-rendered empty dashboard', (tester) async {
    await boot(tester, await leaderAppState(shgId: null));

    expect(find.text("Your account isn't linked to an SHG yet. Contact an Admin to get set up."), findsOneWidget);
    expect(find.text('No pending loan requests'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a leader with a real linked shgId sees the normal dashboard, not the explanatory message', (tester) async {
    await boot(tester, await leaderAppState(shgId: 'shg-1'));

    expect(find.text("Your account isn't linked to an SHG yet. Contact an Admin to get set up."), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
