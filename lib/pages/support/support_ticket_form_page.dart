import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../repositories/support_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class SupportTicketFormPage extends StatefulWidget {
  const SupportTicketFormPage({super.key});
  @override
  State<SupportTicketFormPage> createState() => _SupportTicketFormPageState();
}

class _SupportTicketFormPageState extends State<SupportTicketFormPage> {
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _repo = SupportRepository();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_subject.text.trim().isEmpty) {
      setState(() => _error = l10n.supportTicketFormSubjectRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final appState = context.read<AppState>();
    try {
      final ticketId = await _repo.raiseTicket(
        memberId: appState.profile?.id,
        subject: _subject.text.trim(),
        description: _description.text.trim(),
      );
      if (!mounted) return;
      // Navigate first, then show on the captured messenger — showing
      // before navigating drops the SnackBar, since context.go() replaces
      // this page's Scaffold before it ever gets a frame to render.
      final messenger = ScaffoldMessenger.of(context);
      context.go(ticketId != null ? Paths.supportTicketDetail(ticketId) : Paths.supportChat);
      messenger.showSnackBar(SnackBar(
        content: Text(SupabaseService.isConfigured ? l10n.supportTicketFormRaisedSuccess : l10n.supportTicketFormDemoModeMessage),
      ));
    } catch (_) {
      if (mounted) setState(() => _error = l10n.supportTicketFormRaiseError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: PageHeader(title: l10n.supportTicketFormTitle),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.supportTicketFormSubjectLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _subject,
                    maxLength: 150,
                    textInputAction: TextInputAction.next,
                    style: AppTheme.sans(14),
                    decoration: InputDecoration(border: InputBorder.none, hintText: l10n.supportTicketFormSubjectHint, counterText: ''),
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
                  Text(l10n.supportTicketFormDescriptionLabel, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    maxLength: 1000,
                    textInputAction: TextInputAction.done,
                    style: AppTheme.sans(14),
                    decoration: InputDecoration(border: InputBorder.none, hintText: l10n.supportTicketFormDescriptionHint, counterText: ''),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTheme.sans(12, color: Accent.red600)),
            ],
            const SizedBox(height: 24),
            AppButton(label: _saving ? l10n.supportTicketFormSubmitting : l10n.supportTicketFormSubmit, fullWidth: true, size: ButtonSize.lg, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
    );
  }
}
