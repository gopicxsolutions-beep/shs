import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/marketplace/marketplace_home_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Missing feature: a seller had no way to know a new order arrived at all —
/// `fetchPendingSalesCount` (live-mode only; see its own doc comment for
/// why demo mode can't simulate a real seller/buyer sale) backs a badge on
/// the Orders tile, using `IconTile`'s own `badge` support that had zero
/// callers anywhere in the app before this. Demo mode can't drive a nonzero
/// count (no real seller/buyer split to have "sold" anything to), so this
/// covers the page renders correctly with none — the actual nonzero-count
/// query shape is verified directly against the live database instead (see
/// docs/DEVELOPMENT_PROGRESS.md for that round's entry).
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  testWidgets('renders with no pending-orders badge in demo mode, no exception', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(
          home: const MarketplaceHomePage(),
          localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Orders'), findsOneWidget);
    // The badge is a small circular Container positioned over the tile's
    // icon — absent entirely (not "0") whenever the count is 0, same
    // "hidden rather than shown as zero" convention used elsewhere in this
    // app (e.g. the dashboards' pending-join-request banners).
    expect(find.text('0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
