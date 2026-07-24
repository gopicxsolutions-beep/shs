import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../repositories/marketplace_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../state/unsaved_changes.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/discard_changes_dialog.dart';
import '../../widgets/input_formatters.dart';

// image/jpeg covers both .jpg and .jpeg — `PlatformFile.extension` only ever
// reports one of the 4 extensions the product-images bucket's own allow-list
// permits (`0028_storage_bucket_size_and_type_limits.sql`), so this is
// exhaustive for anything `FileType.image` can actually hand back.
String _imageContentType(String? extension) => switch (extension?.toLowerCase()) {
  'png' => 'image/png',
  'webp' => 'image/webp',
  _ => 'image/jpeg',
};

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});
  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _stock = TextEditingController();
  final _repo = MarketplaceRepository();
  String _category = 'Handicrafts';
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  PlatformFile? _image;

  static const _categories = ['Handicrafts', 'Tailoring', 'Food', 'Agriculture', 'Other'];
  // Matches the sanity-check ceiling already used on `loan_apply_page.dart`
  // and `savings_entry_page.dart` — this field had no upper bound at all,
  // so a stray extra digit (e.g. ₹5000 fat-fingered as ₹500000) would list
  // silently with no warning, unlike its sibling money-entry forms.
  static const _maxPrice = 1000000;
  // Mirrors the `product-images` bucket's own server-side cap
  // (`0028_storage_bucket_size_and_type_limits.sql`) so an oversized image
  // is rejected immediately at picking time with a clear reason, instead of
  // only failing later at upload with a raw `StorageException`.
  static const _maxImageBytes = 5 * 1024 * 1024;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    if (file.size > _maxImageBytes) {
      setState(() => _error = AppLocalizations.of(context)!.addProductImageTooLarge);
      return;
    }
    setState(() {
      _image = file;
      _error = null;
      _markDirty();
    });
  }

  // Also raises the app-wide `UnsavedChanges` flag that `PageHeader`'s Back
  // button and the bottom nav check before navigating away — see
  // `unsaved_changes.dart` for why this page's own `PopScope` below can't
  // cover those two paths by itself.
  void _markDirty() {
    _dirty = true;
    UnsavedChanges.dirty = true;
  }

  @override
  void dispose() {
    UnsavedChanges.dirty = false;
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final price = num.tryParse(_price.text);
    final stock = int.tryParse(_stock.text);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = AppLocalizations.of(context)!.addProductNameRequired);
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = AppLocalizations.of(context)!.addProductInvalidPrice);
      return;
    }
    if (price > _maxPrice) {
      setState(() => _error = AppLocalizations.of(context)!.addProductPriceTooLarge);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    final sellerId = appState.profile?.id;
    try {
      String? imageUrl;
      // Uploaded before the product row is inserted, and inside the same
      // try/catch, so an image that fails to upload doesn't silently list
      // the product without the photo the seller actually chose — the whole
      // submit fails together, surfacing one clear error to retry.
      if (_image != null && SupabaseService.isConfigured && sellerId != null) {
        imageUrl = await _repo.uploadProductImage(
          sellerId: sellerId,
          bytes: _image!.bytes!,
          fileName: _image!.name,
          contentType: _imageContentType(_image!.extension),
        );
      }
      await _repo.addProduct(
        sellerId: sellerId,
        name: _name.text.trim(),
        description: _description.text.trim(),
        price: price,
        stock: stock ?? 0,
        category: _category,
        imageUrl: imageUrl,
      );
      if (mounted) {
        // Navigate first, then show on the captured messenger — showing
        // before navigating drops the SnackBar, since context.go() replaces
        // this page's Scaffold before it ever gets a frame to render.
        final messenger = ScaffoldMessenger.of(context);
        final l10n = AppLocalizations.of(context)!;
        context.go(Paths.marketplace);
        messenger.showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.addProductListedSuccess : l10n.addProductDemoModeNotSaved),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.addProductSubmitError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // A photo is optional — sellers who skip it fall back to the same
  // storefront-icon placeholder every product used to show (see
  // `marketplace_home_page.dart`/`product_detail_page.dart`), so this never
  // blocks listing a product.
  Widget _photoPicker() {
    return AppCard(
      padded: false,
      onTap: _saving ? null : _pickImage,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 140,
          child: _image == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_rounded, size: 28, color: Brand.c500),
                    const SizedBox(height: 8),
                    Text(AppLocalizations.of(context)!.addProductAddPhotoOptional, style: AppTheme.sans(12, weight: FontWeight.w600, color: Neutral.c600)),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(_image!.bytes!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: _saving
                            ? null
                            : () => setState(() {
                                  _image = null;
                                  _markDirty();
                                }),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {String? hint, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, int? maxLength, TextInputAction? textInputAction}) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            textInputAction: textInputAction,
            style: AppTheme.sans(14),
            decoration: InputDecoration(border: InputBorder.none, hintText: hint, counterText: maxLength != null ? '' : null),
            onChanged: (_) => setState(() {
              _error = null;
              _markDirty();
            }),
          ),
        ],
      ),
    );
  }

  // Defense-in-depth for the rare case something genuinely calls
  // `Navigator.pop()` on this page (e.g. if it's ever reached via
  // `context.push()` in the future). Does NOT cover this app's actual
  // navigation triggers today — see `unsaved_changes.dart`.
  Future<void> _handlePop(bool didPop, dynamic result) async {
    if (didPop) return;
    final discard = await confirmDiscardChanges(context);
    if (discard && mounted) {
      UnsavedChanges.dirty = false;
      context.go(Paths.marketplace);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
      appBar: PageHeader(title: l10n.addProductTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _photoPicker(),
            const SizedBox(height: 12),
            _field(l10n.addProductNameLabel, _name, hint: l10n.addProductNameHint, maxLength: 100, textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            _field(l10n.addProductDescriptionLabel, _description, hint: l10n.addProductDescriptionHint, maxLength: 500, textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field(l10n.addProductPriceLabel, _price, hint: '0', keyboardType: TextInputType.number, inputFormatters: decimalAmountInputFormatters, textInputAction: TextInputAction.next, maxLength: 9)),
              const SizedBox(width: 12),
              Expanded(child: _field(l10n.addProductStockLabel, _stock, hint: '0', keyboardType: TextInputType.number, inputFormatters: wholeNumberInputFormatters, textInputAction: TextInputAction.done, maxLength: 6)),
            ]),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.addProductCategoryLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((c) {
                      final selected = c == _category;
                      return ChoiceChip(
                        label: Text(c),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _category = c;
                          _markDirty();
                        }),
                        selectedColor: Brand.c50,
                        labelStyle: AppTheme.sans(12, weight: FontWeight.w600, color: selected ? Brand.c700 : Neutral.c600),
                        backgroundColor: Colors.white,
                        side: BorderSide(color: selected ? Brand.c500 : Neutral.c200),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTheme.sans(12, color: Accent.red600)),
            ],
            const SizedBox(height: 24),
            AppButton(label: _saving ? l10n.addProductListingInProgress : l10n.addProductSubmitButton, fullWidth: true, size: ButtonSize.lg, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
      ),
    );
  }
}
