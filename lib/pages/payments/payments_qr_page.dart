import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../repositories/payment_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/input_formatters.dart';
import '../../widgets/qr_scanner_sheet.dart';

/// Scans a UPI-style QR code (`upi://pay?pa=...&pn=...&am=...`) and prefills
/// the amount/payee from it; manual entry remains the fallback for when no
/// camera exists or the merchant's QR doesn't carry an amount.
class PaymentsQrPage extends StatefulWidget {
  const PaymentsQrPage({super.key});
  @override
  State<PaymentsQrPage> createState() => _PaymentsQrPageState();
}

class _PaymentsQrPageState extends State<PaymentsQrPage> {
  final _amount = TextEditingController();
  final _repo = PaymentRepository();
  String _mode = 'UPI';
  bool _paying = false;
  String? _error;
  String? _payeeName;

  static const _modes = ['UPI', 'QR', 'Card', 'NetBanking'];

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await showQrScanner(context, title: 'Scan to Pay', instructions: 'Point your camera at the merchant\'s UPI QR code');
    if (code == null || !mounted) return;

    String? payee;
    String? amount;
    if (code.startsWith('upi://')) {
      final uri = Uri.tryParse(code);
      payee = uri?.queryParameters['pn'];
      amount = uri?.queryParameters['am'];
    } else if (num.tryParse(code) != null) {
      amount = code;
    }

    setState(() {
      _mode = 'QR';
      _payeeName = payee;
      if (amount != null) _amount.text = amount;
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(amount != null ? 'QR scanned — amount filled in' : 'QR scanned — enter the amount to pay'),
    ));
  }

  Future<void> _pay() async {
    final amount = num.tryParse(_amount.text);
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    setState(() {
      _paying = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    try {
      final result = await _repo.pay(memberId: appState.profile?.id, amount: amount, mode: _mode);
      if (mounted) {
        // Navigate first, then show on the captured messenger — showing
        // before navigating drops the SnackBar, since context.go() replaces
        // this page's Scaffold before it ever gets a frame to render.
        final messenger = ScaffoldMessenger.of(context);
        context.go(Paths.payments);
        messenger.showSnackBar(SnackBar(
          content: Text(result.success ? 'Payment successful · Ref ${result.reference}' : 'Payment failed'),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not process this payment. Please try again.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'Scan & Pay'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _scan,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 160,
                decoration: BoxDecoration(color: Neutral.c100, borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.qr_code_scanner_rounded, size: 48, color: Brand.c600),
                  const SizedBox(height: 8),
                  Text('Tap to scan a QR code', textAlign: TextAlign.center, style: AppTheme.sans(13, weight: FontWeight.w600, color: Neutral.c700)),
                  if (_payeeName != null) ...[
                    const SizedBox(height: 4),
                    Text('Paying $_payeeName', style: AppTheme.sans(11, color: Brand.c600)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('₹', style: AppTheme.display(22)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        inputFormatters: wholeNumberInputFormatters,
                        textInputAction: TextInputAction.done,
                        maxLength: 7,
                        style: AppTheme.display(22),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: '0', counterText: ''),
                        onChanged: (_) => setState(() => _error = null),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Payment mode', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _modes.map((m) {
                      final selected = m == _mode;
                      return ChoiceChip(
                        label: Text(m),
                        selected: selected,
                        onSelected: (_) => setState(() => _mode = m),
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
            AppButton(
              label: _paying ? 'Processing…' : 'Pay Now',
              fullWidth: true,
              size: ButtonSize.lg,
              onPressed: _paying ? null : _pay,
            ),
          ],
        ),
      ),
    );
  }
}
