import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shg_saathi/l10n/gen/app_localizations.dart';
import 'package:shg_saathi/pages/marketplace/add_product_page.dart';
import 'package:shg_saathi/repositories/marketplace_repository.dart';
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
    await tester.ensureVisible(find.text('List Product'));
    await tester.tap(find.text('List Product'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a UPI ID with no @ blocks submit with a validation error', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'e.g. Handwoven Cotton Saree'), 'A test product');
    await tester.enterText(find.widgetWithText(TextField, '0').first, '199');
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 9876543210@upi'), 'no-at-symbol');
    await tester.ensureVisible(find.text('List Product'));
    await tester.tap(find.text('List Product'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid UPI ID (e.g. name@bank)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('edit mode', () {
    // Seeds a real demo-mode listing via the repository directly (not
    // through the UI) so its generated id is knowable, then reopens the
    // page in edit mode against that id — mirrors the same
    // schedule-then-look-up-the-generated-id technique already used in
    // test/pages/meeting_attendance_page_test.dart.
    Future<String> seedProduct(MarketplaceRepository repo, String name) async {
      await repo.addProduct(
        sellerId: null,
        name: name,
        description: 'original description',
        price: 500,
        stock: 3,
        category: 'Food',
        upiId: 'seller@upi',
        paymentNote: 'Cash also accepted',
      );
      final list = await repo.fetchMyProducts(null);
      return list.firstWhere((p) => p.name == name).id;
    }

    Widget editHarness(String id) => ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
          child: MaterialApp(
            home: AddProductPage(productId: id),
            localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        );

    testWidgets('shows the Edit title/button and prefills every field, including UPI details', (tester) async {
      final repo = MarketplaceRepository();
      final id = await seedProduct(repo, '__TEST__ edit-mode product 1');

      await tester.pumpWidget(editHarness(id));
      await tester.pumpAndSettle();

      expect(find.text('Edit Product'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      final nameField = tester.widget<TextField>(find.widgetWithText(TextField, 'e.g. Handwoven Cotton Saree', skipOffstage: false));
      expect(nameField.controller?.text, '__TEST__ edit-mode product 1');
      final upiField = tester.widget<TextField>(find.widgetWithText(TextField, 'e.g. 9876543210@upi', skipOffstage: false));
      expect(upiField.controller?.text, 'seller@upi');
      final noteField = tester.widget<TextField>(find.widgetWithText(TextField, 'Bank details, cash-on-delivery instructions, etc.', skipOffstage: false));
      expect(noteField.controller?.text, 'Cash also accepted');
      expect(tester.takeException(), isNull);
    });

    testWidgets('submitting an edit updates the underlying listing', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MarketplaceRepository();
      final id = await seedProduct(repo, '__TEST__ edit-mode product 2');

      await tester.pumpWidget(editHarness(id));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'e.g. Handwoven Cotton Saree', skipOffstage: false), '__TEST__ edit-mode product 2 (renamed)');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final updated = await repo.fetchProductById(id);
      expect(updated?.name, '__TEST__ edit-mode product 2 (renamed)');
      // Fields never touched by this edit (UPI details, isActive) must
      // survive unchanged, not get wiped by omission.
      expect(updated?.upiId, 'seller@upi');
      expect(updated?.isActive, isTrue);
    });
  });
}
