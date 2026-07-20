import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/shg.dart';
import '../../models/types.dart';
import '../../repositories/savings_repository.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/input_formatters.dart';

class SavingsEntryPage extends StatefulWidget {
  const SavingsEntryPage({super.key});
  @override
  State<SavingsEntryPage> createState() => _SavingsEntryPageState();
}

class _SavingsEntryPageState extends State<SavingsEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _repo = SavingsRepository();
  final _shgRepo = ShgRepository();
  String _mode = 'Cash';
  String _frequency = 'Weekly';
  bool _saving = false;
  String? _error;
  List<Member> _members = [];
  String? _selectedMemberId;
  bool _loadingMembers = true;

  static const _modes = ['Cash', 'UPI', 'Bank Transfer'];
  static const _frequencies = ['Weekly', 'Monthly', 'Daily'];
  static const _maxAmount = 1000000;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final appState = context.read<AppState>();
    if (appState.user.role == Role.member) {
      setState(() => _loadingMembers = false);
      return;
    }
    final members = await _shgRepo.fetchMembers(appState.profile?.shgId);
    if (mounted) {
      setState(() {
        _members = members;
        _loadingMembers = false;
      });
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Enter an amount';
    final amount = num.tryParse(trimmed);
    if (amount == null) return 'Enter a valid number';
    if (amount <= 0) return 'Amount must be greater than zero';
    if (amount > _maxAmount) return 'Amount seems unusually large — please check and re-enter';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final appState = context.read<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    if (isLeaderOrStaff && _selectedMemberId == null) {
      setState(() => _error = 'Select a member');
      return;
    }
    final amount = num.parse(_amount.text.trim());
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _repo.addEntry(
        memberId: isLeaderOrStaff ? _selectedMemberId : appState.profile?.id,
        shgId: appState.profile?.shgId,
        amount: amount,
        mode: _mode,
        frequency: _frequency,
      );
      if (!saved) {
        if (mounted) setState(() => _error = "You're not linked to an SHG, so there's nothing to record this entry against.");
        return;
      }
      if (mounted) {
        // Showing the SnackBar before navigating away silently drops it —
        // context.go() replaces this page's Scaffold before the SnackBar
        // ever gets a frame to render, so the demo-mode disclosure below
        // never reached the user. Capturing the messenger and navigating
        // first, then showing on the (still-live, app-root) messenger,
        // fixes that.
        final messenger = ScaffoldMessenger.of(context);
        context.go(Paths.savings);
        messenger.showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Savings entry submitted for verification' : 'Demo mode — entry not saved (connect Supabase to persist)'),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save this entry. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _chipRow(String label, List<String> options, String value, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((o) {
            final selected = o == value;
            return ChoiceChip(
              label: Text(o),
              selected: selected,
              onSelected: (_) => onChanged(o),
              selectedColor: Brand.c50,
              labelStyle: AppTheme.sans(12, weight: FontWeight.w600, color: selected ? Brand.c700 : Neutral.c600),
              backgroundColor: Colors.white,
              side: BorderSide(color: selected ? Brand.c500 : Neutral.c200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLeaderOrStaff = context.watch<AppState>().user.role != Role.member;
    return Scaffold(
      appBar: const PageHeader(title: 'Add Savings'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLeaderOrStaff) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Member', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                    const SizedBox(height: 8),
                    _loadingMembers
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedMemberId,
                            isExpanded: true,
                            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Select a member'),
                            items: _members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.name))).toList(),
                            onChanged: (v) => setState(() {
                              _selectedMemberId = v;
                              _error = null;
                            }),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  Form(
                    key: _formKey,
                    child: Row(children: [
                      Text('₹', style: AppTheme.display(22)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: false),
                          inputFormatters: wholeNumberInputFormatters,
                          textInputAction: TextInputAction.done,
                          maxLength: 7,
                          style: AppTheme.display(22),
                          decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                          validator: _validateAmount,
                          onChanged: (_) => setState(() => _error = null),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(child: _chipRow('Payment mode', _modes, _mode, (v) => setState(() => _mode = v))),
            const SizedBox(height: 16),
            AppCard(child: _chipRow('Frequency', _frequencies, _frequency, (v) => setState(() => _frequency = v))),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTheme.sans(12, color: Accent.red600)),
            ],
            const SizedBox(height: 24),
            AppButton(label: _saving ? 'Saving…' : 'Submit Entry', fullWidth: true, size: ButtonSize.lg, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
    );
  }
}
