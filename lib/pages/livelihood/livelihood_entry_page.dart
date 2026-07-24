import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../repositories/livelihood_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/input_formatters.dart';

class LivelihoodEntryPage extends StatefulWidget {
  const LivelihoodEntryPage({super.key});
  @override
  State<LivelihoodEntryPage> createState() => _LivelihoodEntryPageState();
}

class _LivelihoodEntryPageState extends State<LivelihoodEntryPage> {
  final _description = TextEditingController();
  final _investment = TextEditingController();
  final _repo = LivelihoodRepository();
  String _activityType = 'Dairy';
  bool _saving = false;
  String? _error;

  static const _types = ['Dairy', 'Tailoring', 'Retail', 'Poultry', 'Agriculture', 'Handicrafts', 'Other'];

  Map<String, String> _typeLabels(AppLocalizations l10n) => {
        'Dairy': l10n.livelihoodEntryTypeDairy,
        'Tailoring': l10n.livelihoodEntryTypeTailoring,
        'Retail': l10n.livelihoodEntryTypeRetail,
        'Poultry': l10n.livelihoodEntryTypePoultry,
        'Agriculture': l10n.livelihoodEntryTypeAgriculture,
        'Handicrafts': l10n.livelihoodEntryTypeHandicrafts,
        'Other': l10n.livelihoodEntryTypeOther,
      };

  @override
  void dispose() {
    _description.dispose();
    _investment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final investment = num.tryParse(_investment.text);
    if (_description.text.trim().isEmpty) {
      setState(() => _error = l10n.livelihoodEntryDescribeRequired);
      return;
    }
    if (investment == null || investment < 0) {
      setState(() => _error = l10n.livelihoodEntryInvalidInvestment);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    try {
      final saved = await _repo.addActivity(
        memberId: appState.profile?.id,
        shgId: appState.profile?.shgId,
        activityType: _activityType,
        description: _description.text.trim(),
        investment: investment,
      );
      if (!saved) {
        if (mounted) setState(() => _error = l10n.livelihoodEntryNoShg);
        return;
      }
      if (mounted) {
        // Navigate first, then show on the captured messenger — showing
        // before navigating drops the SnackBar, since context.go() replaces
        // this page's Scaffold before it ever gets a frame to render.
        final messenger = ScaffoldMessenger.of(context);
        context.go(Paths.livelihood);
        messenger.showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? l10n.livelihoodEntryAdded : l10n.livelihoodEntryDemoMode),
        ));
      }
    } catch (_) {
      if (mounted) setState(() => _error = l10n.livelihoodEntrySaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final typeLabels = _typeLabels(l10n);
    return Scaffold(
      appBar: PageHeader(title: l10n.livelihoodEntryTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.livelihoodEntryActivityTypeLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((t) {
                      final selected = t == _activityType;
                      return ChoiceChip(
                        label: Text(typeLabels[t] ?? t),
                        selected: selected,
                        onSelected: (_) => setState(() => _activityType = t),
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
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.livelihoodEntryDescriptionLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _description,
                    maxLines: 2,
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    style: AppTheme.sans(14),
                    decoration: InputDecoration(border: InputBorder.none, hintText: l10n.livelihoodEntryDescriptionHint, counterText: ''),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.livelihoodEntryInvestmentLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text('₹', style: AppTheme.display(20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _investment,
                        keyboardType: const TextInputType.numberWithOptions(decimal: false),
                        inputFormatters: wholeNumberInputFormatters,
                        textInputAction: TextInputAction.done,
                        maxLength: 9,
                        style: AppTheme.display(20),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: '0', counterText: ''),
                        onChanged: (_) => setState(() => _error = null),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTheme.sans(12, color: Accent.red600)),
            ],
            const SizedBox(height: 24),
            AppButton(label: _saving ? l10n.livelihoodEntrySaving : l10n.livelihoodEntryTitle, fullWidth: true, size: ButtonSize.lg, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
    );
  }
}
