import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/announcement.dart';
import '../../models/types.dart';
import '../../repositories/announcement_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

const _categoryTones = <String, BadgeTone>{
  'Circular': BadgeTone.neutral,
  'Meeting': BadgeTone.brand,
  'Training': BadgeTone.info,
  'Scheme': BadgeTone.warning,
};

class AnnouncementsHomePage extends StatefulWidget {
  const AnnouncementsHomePage({super.key});
  @override
  State<AnnouncementsHomePage> createState() => _AnnouncementsHomePageState();
}

class _AnnouncementsHomePageState extends State<AnnouncementsHomePage> {
  final _repo = AnnouncementRepository();
  final GlobalKey<AppAsyncBuilderState<List<Announcement>>> _key = GlobalKey();
  final _title = TextEditingController();
  final _body = TextEditingController();
  String _category = 'Circular';
  bool _busy = false;

  static const _categories = ['Circular', 'Meeting', 'Training', 'Scheme'];

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post(String? shgId, String? createdBy) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Post announcement'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _title, maxLength: 100, decoration: const InputDecoration(hintText: 'Title')),
              const SizedBox(height: 12),
              TextField(controller: _body, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(hintText: 'Details')),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: _categories.map((c) {
                  final selected = c == _category;
                  return ChoiceChip(label: Text(c), selected: selected, onSelected: (_) => setState(() => _category = c));
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Post')),
          ],
        ),
      ),
    );
    if (confirmed != true || _title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await _repo.post(shgId: shgId, createdBy: createdBy, title: _title.text.trim(), body: _body.text.trim(), category: _category);
      _title.clear();
      _body.clear();
      if (mounted) _key.currentState?.reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final shgId = appState.profile?.shgId;
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: PageHeader(
        title: 'Announcements',
        right: isLeaderOrStaff
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: SupabaseService.isConfigured && !_busy ? Brand.c600 : Neutral.c300),
                onPressed: SupabaseService.isConfigured && !_busy ? () => _post(shgId, memberId) : null,
                tooltip: 'Post announcement',
              )
            : null,
      ),
      body: AppAsyncBuilder<List<Announcement>>(
        key: _key,
        future: () => _repo.fetchForShg(shgId, memberId),
        builder: (context, items) {
          if (items.isEmpty) {
            return const AppEmptyState(icon: Icons.campaign_rounded, message: 'No announcements yet');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  label: a.read ? null : 'Unread',
                  child: AppCard(
                    onTap: () => context.go(Paths.announcementDetail(a.id)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!a.read) Padding(padding: const EdgeInsets.only(top: 5, right: 8), child: Container(width: 6, height: 6, decoration: BoxDecoration(color: Brand.c500, shape: BoxShape.circle))),
                      if (a.read) const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.title, style: AppTheme.sans(13, weight: a.read ? FontWeight.w600 : FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(DateFormat('dd MMM yyyy').format(a.createdAt), style: AppTheme.sans(11, color: Neutral.c400)),
                          ],
                        ),
                      ),
                      AppBadge(text: a.category, tone: _categoryTones[a.category] ?? BadgeTone.neutral),
                    ]),
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
