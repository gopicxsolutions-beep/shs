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
    await tester.enterText(find.widgetWithText(TextField, '0').at(0), '199'); // price
    await tester.enterText(find.widgetWithText(TextField, '0').at(1), '10'); // stock
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
    await tester.enterText(find.widgetWithText(TextField, '0').at(0), '199'); // price
    await tester.enterText(find.widgetWithText(TextField, '0').at(1), '10'); // stock
    await tester.enterText(find.widgetWithText(TextField, 'e.g. 9876543210@upi'), 'no-at-symbol');
    await tester.ensureVisible(find.text('List Product'));
    await tester.tap(find.text('List Product'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid UPI ID (e.g. name@bank)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // User-reported audit gap: `stock` had no validation at all — a blank or
  // unparseable field silently listed the product at `stock ?? 0`,
  // indistinguishable from a deliberate "sold out" listing.
  testWidgets('a blank stock field blocks submit with a validation error', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'e.g. Handwoven Cotton Saree'), 'A test product');
    await tester.enterText(find.widgetWithText(TextField, '0').at(0), '199'); // price only — stock left blank
    await tester.ensureVisible(find.text('List Product'));
    await tester.tap(find.text('List Product'));
    await tester.pumpAndSettle();

    expect(find.text('Enter how many are in stock (0 or more)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stock of exactly 0 is accepted — it is a legitimate "sold out but still listed" value', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'e.g. Handwoven Cotton Saree'), 'A test product');
    await tester.enterText(find.widgetWithText(TextField, '0').at(0), '199');
    await tester.enterText(find.widgetWithText(TextField, '0').at(1), '0');
    await tester.ensureVisible(find.text('List Product'));
    await tester.tap(find.text('List Product'));
    await tester.pumpAndSettle();

    expect(find.text('Enter how many are in stock (0 or more)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('edit mode', () {
    // Seeds a real demo-mode listing via the repository directly (not
    // through the UI) so its generated id is knowable, then reopens the
    // page in edit mode against that id — mirrors the same
    // schedule-then-look-up-the-generated-id technique already used in
    // test/pages/meeting_attendance_page_test.dart.
    Future<String> seedProduct(MarketplaceRepository repo, String name, {String? imageUrl}) async {
      await repo.addProduct(
        sellerId: null,
        name: name,
        description: 'original description',
        price: 500,
        stock: 3,
        category: 'Food',
        upiId: 'seller@upi',
        paymentNote: 'Cash also accepted',
        imageUrl: imageUrl,
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

    // Marketplace audit finding: opening Edit on a listing that already had
    // a photo showed the EMPTY "Add a photo" placeholder anyway — the photo
    // picker only ever checked a freshly-picked file, never the existing
    // photo `_loadForEdit` had already fetched — indistinguishable from "the
    // photo is gone," even though it was silently still there and would
    // have been echoed back unchanged on save.
    testWidgets('edit mode shows the existing photo (not the empty placeholder), with a remove control', (tester) async {
      final repo = MarketplaceRepository();
      final id = await seedProduct(repo, '__TEST__ edit-mode product 3', imageUrl: 'https://example.com/photo.jpg');

      await tester.pumpWidget(editHarness(id));
      await tester.pumpAndSettle();

      expect(find.text('Add a photo (optional)'), findsNothing, reason: 'this was the bug: an existing photo looked identical to having none at all');
      expect(find.byTooltip('Remove photo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // Second bug found in the same area, same root cause:
    // MarketplaceRepository.updateProduct used the null-aware `?field`
    // spread for image_url/upi_id/payment_note, which OMITS the key
    // entirely whenever the value is null — so clearing any of these three
    // fields and saving silently left the OLD value in the database,
    // reappearing right back if she reopened Edit.
    //
    // These next two tests only cover the WIDGET-level behavior (the
    // picker/field correctly reaching a null value and calling through) —
    // demo mode's updateProduct() constructs a Product object directly and
    // was never affected by the `?field` bug at all (that's Dart map-literal
    // syntax specific to the live branch's real PostgREST .update() call),
    // so they can't by themselves prove the live-mode fix. That half is
    // verified separately, live against the real database, rolled back: an
    // explicit `image_url: null, upi_id: null, payment_note: null` UPDATE —
    // exactly the shape this method's live branch now always sends —
    // confirmed to actually persist as NULL (see this round's
    // DEVELOPMENT_PROGRESS.md entry).
    testWidgets('removing the existing photo and saving actually clears it', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MarketplaceRepository();
      final id = await seedProduct(repo, '__TEST__ edit-mode product 4', imageUrl: 'https://example.com/photo.jpg');

      await tester.pumpWidget(editHarness(id));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Remove photo'));
      await tester.pumpAndSettle();
      expect(find.text('Add a photo (optional)'), findsOneWidget);

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final updated = await repo.fetchProductById(id);
      expect(updated?.imageUrl, isNull, reason: 'this was the bug: the OLD photo URL used to survive the save untouched');
    });

    testWidgets('clearing the UPI ID field and saving actually clears it', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repo = MarketplaceRepository();
      final id = await seedProduct(repo, '__TEST__ edit-mode product 5');

      await tester.pumpWidget(editHarness(id));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'e.g. 9876543210@upi', skipOffstage: false), '');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final updated = await repo.fetchProductById(id);
      expect(updated?.upiId, isNull, reason: 'this was the bug: the OLD UPI ID used to survive the save untouched');
    });
  });
}
