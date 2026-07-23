import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/marketplace/add_product_page.dart';
import 'package:shg_saathi/services/supabase_service.dart';
import 'package:shg_saathi/state/app_state.dart';

/// Regression coverage for the photo-picker card added to Add Product.
/// Doesn't tap "Add a photo (optional)" itself — that invokes `file_picker`'s
/// real platform channel, unavailable/unmocked under `flutter test` (same
/// class of limitation already documented for the camera QR scanner and
/// voice mic elsewhere in this app) — just confirms the placeholder renders
/// and that submitting without ever picking a photo still works, since a
/// photo is optional.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  Widget harness() => ChangeNotifierProvider<AppState>(
        create: (_) => AppState(),
        child: MaterialApp(home: const AddProductPage(), localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate], supportedLocales: AppLocalizations.supportedLocales, ),
      );

  testWidgets('renders the optional photo placeholder with no exceptions', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Add a photo (optional)'), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('submitting a valid product with no photo chosen still lists it', (tester) async {
    // The default 800x600 test surface is too short to fit "List Product"
    // on screen without scrolling (same fix already used elsewhere in this
    // suite, e.g. test/routes/all_routes_smoke_test.dart) — size like a
    // real phone so the tap actually lands on the button.
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'e.g. Handwoven Cotton Saree'), 'A test product');
    await tester.enterText(find.widgetWithText(TextField, '0').first, '199');
    await tester.tap(find.text('List Product'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
