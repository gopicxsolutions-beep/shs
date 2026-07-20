import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/shg.dart';
import '../../models/types.dart';
import '../../repositories/shg_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

/// Lets an admin create new SHGs. Without this page, `shgs_insert_staff`
/// (the RLS policy already permitting any staff role to insert one — see
/// supabase/migrations/0002_rls_policies.sql) had no client anywhere that
/// called it. On a fresh deployment with zero SHGs seeded, that's not a
/// cosmetic gap: profile setup requires picking an existing SHG to
/// continue, so nobody — not even a future admin, who has no SHG to begin
/// with — could ever finish onboarding. See profile_setup_page.dart's fix
/// making that selection optional; this page is the other half, giving an
/// admin (once one exists) a real way to grow the catalog afterward instead
/// of needing direct database access every time.
class AdminShgsPage extends StatefulWidget {
  const AdminShgsPage({super.key});
  @override
  State<AdminShgsPage> createState() => _AdminShgsPageState();
}

class _AdminShgsPageState extends State<AdminShgsPage> {
  final _repo = ShgRepository();
  final GlobalKey<AppAsyncBuilderState<List<ShgProfile>>> _key = GlobalKey();
  final _name = TextEditingController();
  final _village = TextEditingController();
  final _district = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _village.dispose();
    _district.dispose();
    super.dispose();
  }

  Future<void> _addShg() async {
    _name.clear();
    _village.clear();
    _district.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add SHG'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _name, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'SHG name')),
            const SizedBox(height: 12),
            TextField(controller: _village, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Village')),
            const SizedBox(height: 12),
            TextField(controller: _district, maxLength: 100, textInputAction: TextInputAction.done, decoration: const InputDecoration(hintText: 'District')),
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
      await _repo.createShg(name: _name.text.trim(), village: _village.text.trim(), district: _district.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(SupabaseService.isConfigured ? 'SHG added' : 'Demo mode — SHG not saved (connect Supabase to persist)'),
        ));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not add this SHG. Please try again.')));
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
        title: 'Manage SHGs',
        right: isAdmin
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: !_busy ? Brand.c600 : Neutral.c300),
                onPressed: !_busy ? _addShg : null,
                tooltip: 'Add SHG',
              )
            : null,
      ),
      body: AppAsyncBuilder<List<ShgProfile>>(
        key: _key,
        future: _repo.fetchAllShgs,
        builder: (context, shgs) {
          if (shgs.isEmpty) {
            return const AppEmptyState(icon: Icons.groups_rounded, message: 'No SHGs registered yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shgs.length,
            itemBuilder: (context, i) {
              final s = shgs[i];
              final location = [s.village, s.district].where((p) => p != null && p.isNotEmpty).join(', ');
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
                            if (location.isNotEmpty) Text(location, style: AppTheme.sans(11, color: Neutral.c500)),
                          ],
                        ),
                      ),
                      if (s.grade != null) Text(s.grade!, style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
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
