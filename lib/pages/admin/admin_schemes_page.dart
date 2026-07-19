import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/scheme.dart';
import '../../models/types.dart';
import '../../repositories/scheme_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class AdminSchemesPage extends StatefulWidget {
  const AdminSchemesPage({super.key});
  @override
  State<AdminSchemesPage> createState() => _AdminSchemesPageState();
}

class _AdminSchemesPageState extends State<AdminSchemesPage> {
  final _repo = SchemeRepository();
  final GlobalKey<AppAsyncBuilderState<List<Scheme>>> _key = GlobalKey();
  final _name = TextEditingController();
  final _agency = TextEditingController();
  final _benefit = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _agency.dispose();
    _benefit.dispose();
    super.dispose();
  }

  Future<void> _addScheme() async {
    _name.clear();
    _agency.clear();
    _benefit.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add scheme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Scheme name')),
            const SizedBox(height: 12),
            TextField(controller: _agency, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Agency')),
            const SizedBox(height: 12),
            TextField(controller: _benefit, maxLength: 300, textInputAction: TextInputAction.done, decoration: const InputDecoration(hintText: 'Benefit')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Add')),
        ],
      ),
    );
    if (confirmed != true || _name.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _repo.createScheme(name: _name.text.trim(), agency: _agency.text.trim(), benefit: _benefit.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Scheme added' : 'Demo mode — scheme not saved (connect Supabase to persist)'),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add this scheme. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteScheme(Scheme s) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete scheme?'),
        content: Text('This removes "${s.name}" from the catalog.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteScheme(s.id);
      if (mounted) {
        _key.currentState?.reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'Scheme deleted' : 'Demo mode — not saved (connect Supabase to persist)'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete this scheme. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AppState>().user.role == Role.admin;

    return Scaffold(
      appBar: PageHeader(
        title: 'Manage Schemes',
        right: isAdmin
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: !_busy ? Brand.c600 : Neutral.c300),
                onPressed: !_busy ? _addScheme : null,
                tooltip: 'Add scheme',
              )
            : null,
      ),
      body: AppAsyncBuilder<List<Scheme>>(
        key: _key,
        future: _repo.fetchSchemes,
        builder: (context, schemes) {
          if (schemes.isEmpty) {
            return const AppEmptyState(icon: Icons.description_rounded, message: 'No schemes in the catalog yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: schemes.length,
            itemBuilder: (context, i) {
              final s = schemes[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.name, style: AppTheme.sans(13, weight: FontWeight.w700)),
                            if (s.agency != null) Text(s.agency!, style: AppTheme.sans(11, color: Neutral.c500)),
                          ],
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: !_busy ? Accent.red500 : Neutral.c300),
                          onPressed: !_busy ? () => _deleteScheme(s) : null,
                          tooltip: 'Delete ${s.name}',
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
