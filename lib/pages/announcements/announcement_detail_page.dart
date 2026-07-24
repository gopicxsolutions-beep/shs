import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/announcement.dart';
import '../../repositories/announcement_repository.dart';
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

class AnnouncementDetailPage extends StatefulWidget {
  final String announcementId;
  const AnnouncementDetailPage({super.key, required this.announcementId});
  @override
  State<AnnouncementDetailPage> createState() => _AnnouncementDetailPageState();
}

class _AnnouncementDetailPageState extends State<AnnouncementDetailPage> {
  final _repo = AnnouncementRepository();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final memberId = appState.profile?.id;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.announcementDetailTitle),
      body: AppAsyncBuilder<Announcement?>(
        future: () async {
          final a = await _repo.fetchById(widget.announcementId, memberId);
          if (a != null) {
            try {
              await _repo.markRead(widget.announcementId, memberId);
            } catch (_) {
              // read-receipt failure must not hide successfully-loaded content
            }
          }
          return a;
        },
        builder: (context, a) {
          if (a == null) {
            return AppEmptyState(icon: Icons.error_outline_rounded, message: l10n.announcementDetailNotFound);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(a.title, style: AppTheme.display(17))),
                      AppBadge(text: a.category, tone: _categoryTones[a.category] ?? BadgeTone.neutral),
                    ]),
                    const SizedBox(height: 6),
                    Text(DateFormat('dd MMM yyyy').format(a.createdAt), style: AppTheme.sans(11, color: Neutral.c500)),
                    if (a.body != null) ...[
                      const SizedBox(height: 16),
                      Text(a.body!, style: AppTheme.sans(14, color: Neutral.c700)),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
