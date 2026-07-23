import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/training.dart';
import '../../repositories/training_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/section_header.dart';

const _formatIcons = <String, IconData>{
  'Video': Icons.play_circle_rounded,
  'PDF': Icons.picture_as_pdf_rounded,
  'Audio': Icons.headphones_rounded,
};

class _TrainingData {
  final List<Course> courses;
  final Map<String, CourseProgress> progress;
  const _TrainingData(this.courses, this.progress);
}

class TrainingHomePage extends StatelessWidget {
  const TrainingHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = TrainingRepository();
    final memberId = appState.profile?.id;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(
        title: l10n.trainingHomeTitle,
        right: IconButton(icon: const Icon(Icons.workspace_premium_rounded, color: Brand.c600), onPressed: () => context.go(Paths.trainingCertificates), tooltip: l10n.trainingHomeCertificatesTooltip),
      ),
      body: AppAsyncBuilder<_TrainingData>(
        future: () async {
          final courses = await repo.fetchCourses();
          final progress = await repo.fetchMyProgress(memberId);
          return _TrainingData(courses, progress);
        },
        builder: (context, data) {
          if (data.courses.isEmpty) {
            return AppEmptyState(icon: Icons.school_rounded, message: l10n.trainingHomeEmpty);
          }
          // CustomScrollView/Sliver split so the course list is genuinely
          // lazy (`SliverList.builder`) instead of every card getting built
          // eagerly via `...data.courses.map(...)` in a plain `ListView`.
          // Unlike an SHG's member/loan lists (bounded to that group's
          // ~10-30 members), this is the platform-wide training catalog
          // shared by every SHG — it grows as more content is added over
          // time, not by any one group's size, so it's not safe to assume
          // it stays small.
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(child: SectionHeader(title: l10n.trainingHomeCoursesSection)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.builder(
                  itemCount: data.courses.length,
                  itemBuilder: (context, i) {
                    final c = data.courses[i];
                    final p = data.progress[c.id];
                    final pct = p?.progress ?? 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        onTap: () => context.go(Paths.trainingDetail(c.id)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(width: 40, height: 40, decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(12)), child: Icon(_formatIcons[c.format] ?? Icons.school_rounded, color: Brand.c600, size: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.title, style: AppTheme.sans(13, weight: FontWeight.w700)),
                                    Text('${c.topic} · ${c.duration ?? ''}', style: AppTheme.sans(11, color: Neutral.c500)),
                                  ],
                                ),
                              ),
                              Flexible(
                                child: p?.certified == true
                                    ? AppBadge(text: l10n.trainingHomeCertifiedBadge, tone: BadgeTone.success)
                                    : Text('$pct%', overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
                              ),
                            ]),
                            const SizedBox(height: 10),
                            AppProgressBar(value: pct, tone: pct == 100 ? ProgressTone.brand : ProgressTone.gold),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
