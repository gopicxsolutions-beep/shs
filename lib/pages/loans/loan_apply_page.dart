import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../repositories/loan_repository.dart';
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

class LoanApplyPage extends StatefulWidget {
  const LoanApplyPage({super.key});
  @override
  State<LoanApplyPage> createState() => _LoanApplyPageState();
}

class _LoanApplyPageState extends State<LoanApplyPage> {
  final _purpose = TextEditingController();
  final _amount = TextEditingController();
  final _repo = LoanRepository();
  int _tenure = 12;
  bool _saving = false;
  bool _dirty = false;
  String? _error;

  static const _tenureOptions = [6, 12, 18, 24];
  static const _maxAmount = 1000000;

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
    _purpose.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = num.tryParse(_amount.text);
    if (_purpose.text.trim().isEmpty) {
      setState(() => _error = 'Describe what the loan is for');
      return;
    }
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    if (amount > _maxAmount) {
      setState(() => _error = 'Amount seems unusually large — please check and re-enter');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    try {
      final saved = await _repo.apply(
        memberId: appState.profile?.id,
        shgId: appState.profile?.shgId,
        purpose: _purpose.text.trim(),
        amount: amount,
        tenureMonths: _tenure,
      );
      if (!saved) {
        if (mounted) setState(() => _error = "You're not linked to an SHG, so there's nothing to apply for this loan against.");
        return;
      }
      if (mounted) {
        // Navigate first, then show on the captured messenger — showing
        // before navigating drops the SnackBar, since context.go() replaces
        // this page's Scaffold before it ever gets a frame to render.
        final messenger = ScaffoldMessenger.of(context);
        context.go(Paths.loans);
        messenger.showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Loan application submitted for review' : 'Demo mode — application not saved (connect Supabase to persist)'),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not submit this application. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      context.go(Paths.loans);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
      appBar: const PageHeader(title: 'Apply for Loan'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Purpose', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _purpose,
                    maxLines: 2,
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    style: AppTheme.sans(14),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'e.g. Dairy — buy milch cow', counterText: ''),
                    onChanged: (_) => setState(() {
                      _error = null;
                      _markDirty();
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount requested', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
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
                        onChanged: (_) => setState(() {
                          _error = null;
                          _markDirty();
                        }),
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
                  Text('Tenure', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _tenureOptions.map((t) {
                      final selected = t == _tenure;
                      return ChoiceChip(
                        label: Text('$t months'),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _tenure = t;
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
            AppButton(label: _saving ? 'Submitting…' : 'Submit Application', fullWidth: true, size: ButtonSize.lg, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
      ),
    );
  }
}
