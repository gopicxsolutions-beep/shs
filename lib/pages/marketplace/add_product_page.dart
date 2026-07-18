import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../repositories/marketplace_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
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
  String? _error;

  static const _categories = ['Handicrafts', 'Tailoring', 'Food', 'Agriculture', 'Other'];

  @override
  void dispose() {
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Product listed' : 'Demo mode — product not saved (connect Supabase to persist)'),
        ));
        context.go(Paths.marketplace);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not list this product. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController controller, {String? hint, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, int? maxLength}) {
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
            style: AppTheme.sans(14),
            decoration: InputDecoration(border: InputBorder.none, hintText: hint, counterText: maxLength != null ? '' : null),
            onChanged: (_) => setState(() => _error = null),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'Add Product'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field('Product name', _name, hint: 'e.g. Handwoven Cotton Saree', maxLength: 100),
            const SizedBox(height: 12),
            _field('Description', _description, hint: 'Describe your product', maxLength: 500),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _field('Price (₹)', _price, hint: '0', keyboardType: TextInputType.number, inputFormatters: decimalAmountInputFormatters)),
              const SizedBox(width: 12),
              Expanded(child: _field('Stock', _stock, hint: '0', keyboardType: TextInputType.number, inputFormatters: wholeNumberInputFormatters)),
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
                        onSelected: (_) => setState(() => _category = c),
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
    );
  }
}
