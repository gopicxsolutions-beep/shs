import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/marketplace.dart';
import 'package:shg_saathi/models/shg.dart';
import 'package:shg_saathi/repositories/marketplace_repository.dart';
import 'package:shg_saathi/repositories/shg_repository.dart';
import 'package:shg_saathi/services/supabase_service.dart';

/// Regression coverage for the real file/image upload wiring added on top of
/// the previously metadata-only "Add document" (SHG Documents) and
/// "Add product" (Marketplace) flows. The actual Storage `.uploadBinary()`/
/// `.createSignedUrl()` calls need a live Supabase project (covered by this
/// session's manual live-mode verification, documented in
/// docs/DEVELOPMENT_PROGRESS.md), but the demo-mode round-trip and the model
/// mapping for the new `imageUrl`/`storagePath` fields are pure Dart logic
/// this suite can verify directly.
void main() {
  setUp(() {
    SupabaseService.isConfigured = false;
  });

  group('Product model', () {
    test('fromMap maps image_url to imageUrl', () {
      final product = Product.fromMap({
        'id': 'p1',
        'seller_id': 's1',
        'name': 'Handwoven Saree',
        'price': 500,
        'stock': 3,
        'image_url': 'https://example.supabase.co/storage/v1/object/public/product-images/s1/x.jpg',
      });
      expect(product.imageUrl, 'https://example.supabase.co/storage/v1/object/public/product-images/s1/x.jpg');
    });

    test('fromMap tolerates a missing image_url (pre-existing products with no photo)', () {
      final product = Product.fromMap({'id': 'p1', 'seller_id': 's1', 'name': 'Old listing', 'price': 100, 'stock': 1});
      expect(product.imageUrl, isNull);
    });
  });

  group('ShgDocument model', () {
    test('fromMap maps storage_path to storagePath', () {
      final doc = ShgDocument.fromMap({'id': 'd1', 'name': 'Bylaws', 'storage_path': 'shg-1/123_bylaws.pdf', 'created_at': '2026-01-01T00:00:00Z'});
      expect(doc.storagePath, 'shg-1/123_bylaws.pdf');
    });

    test('fromMap tolerates a missing storage_path (metadata-only records predating this feature)', () {
      final doc = ShgDocument.fromMap({'id': 'd1', 'name': 'Old record', 'created_at': '2026-01-01T00:00:00Z'});
      expect(doc.storagePath, isNull);
    });
  });

  group('demo-mode round-trip (no live Storage bucket, no file_picker platform call)', () {
    test('MarketplaceRepository.addProduct persists the passed imageUrl for the rest of the session', () async {
      final repo = MarketplaceRepository();
      await repo.addProduct(
        sellerId: 'seller-1',
        name: 'Test Product With Photo',
        description: 'desc',
        price: 250,
        stock: 5,
        category: 'Handicrafts',
        imageUrl: 'https://example.com/picked-locally.jpg',
      );
      final products = await repo.fetchProducts();
      final added = products.firstWhere((p) => p.name == 'Test Product With Photo');
      expect(added.imageUrl, 'https://example.com/picked-locally.jpg');
    });

    test('MarketplaceRepository.addProduct without an image leaves imageUrl null (photo is optional)', () async {
      final repo = MarketplaceRepository();
      await repo.addProduct(sellerId: 'seller-1', name: 'Test Product No Photo', description: 'desc', price: 100, stock: 2, category: 'Other');
      final products = await repo.fetchProducts();
      final added = products.firstWhere((p) => p.name == 'Test Product No Photo');
      expect(added.imageUrl, isNull);
    });

    test('ShgRepository.addDocument persists the passed size for the rest of the session', () async {
      final repo = ShgRepository();
      final saved = await repo.addDocument(shgId: 'shg-1', name: 'Test Uploaded Doc', type: 'PDF', size: '245 KB');
      expect(saved, isTrue);
      final docs = await repo.fetchDocuments('shg-1');
      final added = docs.firstWhere((d) => d.name == 'Test Uploaded Doc');
      expect(added.size, '245 KB');
      // Demo mode never uploads to a real bucket, so there's genuinely no
      // storage path to attach — the download action correctly treats this
      // the same as a pre-existing metadata-only record.
      expect(added.storagePath, isNull);
    });
  });
}
