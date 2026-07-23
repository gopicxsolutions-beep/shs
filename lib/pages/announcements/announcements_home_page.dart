import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/announcement.dart';
import '../../models/types.dart';
import '../../repositories/announcement_repository.dart';
import '../../routes/paths.dart';
import '../../services/notification_service.dart';
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
  // Injectable for tests (mirrors `SettingsPage`'s `notificationService`
  // seam) — defaults to the real on-device implementation.
  final NotificationService? notificationService;
  const AnnouncementsHomePage({super.key, this.notificationService});
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

  late final NotificationService _notifications = widget.notificationService ?? LocalNotificationService.instance;

  /// Fetches this SHG's announcements and, best-effort and without blocking
  /// the list from rendering, fires an immediate local notification for any
  /// the member hasn't already been notified about on this device (see
  /// `notifyNewAnnouncements`'s doc comment for the "already seen" bookkeeping
  /// that keeps this from re-firing for the same announcement).
  ///
  /// Before deciding, this also proactively requests the OS notification
  /// permission the first time this ever loads with the preference still at
  /// its untouched, enabled-by-default state — see
  /// `ensureNotificationPermissionForDefaultEnabled`'s doc comment — instead
  /// of only ever asking reactively when a member happens to visit Settings.
  ///
  /// Bug fix: that permission check/notify step used to be `await`ed before
  /// returning `items` to `AppAsyncBuilder` below — meaning the list this
  /// method is documented as "without blocking...rendering" was, in fact,
  /// held behind whatever the real on-device OS permission round trip
  /// happened to take (a single request/response call for a user actually
  /// present, but a two-way native handshake that can legitimately never
  /// resolve at all in an environment with no native counterpart to answer
  /// it — this app's own `flutter test` suite, which uses this page's
  /// default real [LocalNotificationService.instance] whenever a test
  /// doesn't inject a fake, hit exactly that and hung on `pumpAndSettle`
  /// forever). Firing this off with [unawaited] instead means the
  /// already-fetched `items` render immediately regardless of how long (or
  /// whether) the permission dance ever resolves.
  Future<List<Announcement>> _loadAndNotify(String? shgId, String? memberId) async {
    final items = await _repo.fetchForShg(shgId, memberId);
    unawaited(_syncNotifications(items));
    return items;
  }

  Future<void> _syncNotifications(List<Announcement> items) async {
    final enabled = await ensureNotificationPermissionForDefaultEnabled(_notifications, kNotifyAnnouncementsPrefKey, await announcementNotificationsEnabled());
    if (enabled) {
      await notifyNewAnnouncements(_notifications, items);
    }
  }

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
              TextField(controller: _title, maxLength: 100, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: 'Title')),
              const SizedBox(height: 12),
              TextField(controller: _body, maxLines: 3, maxLength: 1000, textInputAction: TextInputAction.done, decoration: const InputDecoration(hintText: 'Details')),
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
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(AppLocalizations.of(context)?.actionCancel ?? 'Cancel')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Post')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    if (_title.text.trim().isEmpty) {
      // Without this, tapping "Post" on a blank title silently closed the
      // dialog and posted nothing — indistinguishable from a broken button,
      // same silent-no-op gap already fixed for "Add SHG"/"Add scheme" in
      // admin_shgs_page.dart / admin_schemes_page.dart.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title is required.')));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final posted = await _repo.post(shgId: shgId, createdBy: createdBy, title: _title.text.trim(), body: _body.text.trim(), category: _category);
      if (!mounted) return;
      if (!posted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You're not linked to an SHG, so there's nothing to post this announcement to.")),
        );
        return;
      }
      _title.clear();
      _body.clear();
      _key.currentState?.reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not post this announcement. Please try again.')),
        );
      }
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
        future: () => _loadAndNotify(shgId, memberId),
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
                  label: [
                    if (!a.read) 'Unread',
                    a.title,
                    DateFormat('dd MMM yyyy').format(a.createdAt),
                    a.category,
                  ].join(', '),
                  button: true,
                  onTap: () => context.go(Paths.announcementDetail(a.id)),
                  child: ExcludeSemantics(
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
