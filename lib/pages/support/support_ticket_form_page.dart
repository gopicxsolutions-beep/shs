import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
    if (_subject.text.trim().isEmpty) {
      setState(() => _error = 'Enter a subject for your issue');
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(SupabaseService.isConfigured ? 'Ticket raised' : 'Demo mode — ticket not saved (connect Supabase to persist)'),
      ));
      context.go(ticketId != null ? Paths.supportTicketDetail(ticketId) : Paths.supportChat);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not raise this ticket. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'Raise a Ticket'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Subject', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _subject,
                    style: AppTheme.sans(14),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'e.g. Loan disbursement delay'),
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
                  Text('Describe your issue', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    style: AppTheme.sans(14),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Give as much detail as you can'),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: AppTheme.sans(12, color: Accent.red600)),
            ],
            const SizedBox(height: 24),
            AppButton(label: _saving ? 'Submitting…' : 'Submit Ticket', fullWidth: true, size: ButtonSize.lg, onPressed: _saving ? null : _submit),
          ],
        ),
      ),
    );
  }
}
