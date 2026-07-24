import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/training.dart';
import '../../repositories/training_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class _CertificateData {
  final Course course;
  final DateTime? completedOn;
  const _CertificateData(this.course, this.completedOn);
}

class CertificatesPage extends StatelessWidget {
  const CertificatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = TrainingRepository();
    final memberId = appState.profile?.id;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.certificatesTitle),
      body: AppAsyncBuilder<List<_CertificateData>>(
        future: () async {
          final courses = await repo.fetchCertificates(memberId);
          // `CourseProgress.completedOn` (`course_progress.completed_on`)
          // was parsed by `TrainingRepository.fetchMyProgress()` but never
          // displayed anywhere — `fetchCertificates()` itself drops the
          // progress data entirely, returning bare `Course`s. Re-fetching
          // progress here (same call `CourseDetailPage` already makes) lets
          // this page show when each certificate was actually earned.
          final progress = await repo.fetchMyProgress(memberId);
          return courses.map((c) => _CertificateData(c, progress[c.id]?.completedOn)).toList();
        },
        builder: (context, certificates) {
          if (certificates.isEmpty) {
            return AppEmptyState(icon: Icons.workspace_premium_rounded, message: l10n.certificatesEmptyState);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: certificates.length,
            itemBuilder: (context, i) {
              final cert = certificates[i];
              final c = cert.course;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: Gold.c50, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.workspace_premium_rounded, color: Gold.c600, size: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: AppTheme.sans(13, weight: FontWeight.w700)),
                          Text(
                            cert.completedOn != null
                                ? l10n.certificatesCompletedOn(c.topic, DateFormat('dd MMM yyyy').format(cert.completedOn!))
                                : c.topic,
                            style: AppTheme.sans(11, color: Neutral.c500),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
