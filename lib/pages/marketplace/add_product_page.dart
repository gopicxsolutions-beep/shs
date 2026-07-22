import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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

  static const _categories = ['Handicrafts', 'Tailoring', 'Food', 'Agriculture', 'Other'];
  // Matches the sanity-check ceiling already used on `loan_apply_page.dart`
  // and `savings_entry_page.dart` — this field had no upper bound at all,
  // so a stray extra digit (e.g. ₹5000 fat-fingered as ₹500000) would list
  // silently with no warning, unlike its sibling money-entry forms.
  static const _maxPrice = 1000000;

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
      setState(() => _error = 'Enter a product name');
      return;
    }
    if (price == null || price <= 0) {
      setState(() => _error = 'Enter a valid price');
      return;
    }
    if (price > _maxPrice) {
      setState(() => _error = 'Price seems unusually large — please check and re-enter');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    try {
      await _repo.addProduct(
        sellerId: appState.profile?.id,
        name: _name.text.trim(),
        description: _description.text.trim(),
        price: price,
        stock: stock ?? 0,
        category: _category,
      );
      if (mounted) {
        // Navigate first, then show on the captured messenger — showing
        // before navigating drops the SnackBar, since context.go() replaces
        // this page's Scaffold before it ever gets a frame to render.
        final messenger = ScaffoldMessenger.of(context);
        context.go(Paths.marketplace);
        messenger.showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Product listed' : 'Demo mode — product not saved (connect Supabase to persist)'),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not list this product. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
      appBar: const PageHeader(title: 'Add Product'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('Product name', _name, hint: 'e.g. Handwoven Cotton Saree', maxLength: 100, textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            _field('Description', _description, hint: 'Describe your product', maxLength: 500, textInputAction: TextInputAction.next),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('Price (₹)', _price, hint: '0', keyboardType: TextInputType.number, inputFormatters: decimalAmountInputFormatters, textInputAction: TextInputAction.next, maxLength: 9)),
              const SizedBox(width: 12),
              Expanded(child: _field('Stock', _stock, hint: '0', keyboardType: TextInputType.number, inputFormatters: wholeNumberInputFormatters, textInputAction: TextInputAction.done, maxLength: 6)),
            ]),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Category', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
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
            AppButton(label: _saving ? 'Listing…' : 'List Product', fullWidth: true, size: ButtonSize.lg, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
      ),
    );
  }
}
