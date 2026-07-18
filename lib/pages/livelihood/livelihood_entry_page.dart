import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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

  @override
  void dispose() {
    _description.dispose();
    _investment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final investment = num.tryParse(_investment.text);
    if (_description.text.trim().isEmpty) {
      setState(() => _error = 'Describe the activity');
      return;
    }
    if (investment == null || investment < 0) {
      setState(() => _error = 'Enter a valid investment amount');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    try {
      await _repo.addActivity(
        memberId: appState.profile?.id,
        shgId: appState.profile?.shgId,
        activityType: _activityType,
        description: _description.text.trim(),
        investment: investment,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Activity added' : 'Demo mode — activity not saved (connect Supabase to persist)'),
        ));
        context.go(Paths.livelihood);
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save this activity. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'Add Activity'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Activity type', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((t) {
                      final selected = t == _activityType;
                      return ChoiceChip(
                        label: Text(t),
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
                  Text('Description', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _description,
                    maxLines: 2,
                    maxLength: 200,
                    textInputAction: TextInputAction.next,
                    style: AppTheme.sans(14),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'e.g. Milch cow rearing — 2 cows', counterText: ''),
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
                  Text('Initial investment', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
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
                        style: AppTheme.display(20),
                        decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
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
            AppButton(label: _saving ? 'Saving…' : 'Add Activity', fullWidth: true, size: ButtonSize.lg, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
    );
  }
}
