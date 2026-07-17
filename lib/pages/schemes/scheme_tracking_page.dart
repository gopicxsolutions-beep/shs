import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/scheme.dart';
import '../../repositories/scheme_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/list_row.dart';

const _statusTones = <String, BadgeTone>{
  'applied': BadgeTone.warning,
  'under_review': BadgeTone.info,
  'approved': BadgeTone.success,
  'rejected': BadgeTone.danger,
};

class _TrackingRow {
  final Scheme scheme;
  final SchemeApplication application;
  const _TrackingRow(this.scheme, this.application);
}

class SchemeTrackingPage extends StatelessWidget {
  const SchemeTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = SchemeRepository();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Application Tracking'),
      body: AppAsyncBuilder<List<_TrackingRow>>(
        future: () async {
          final schemes = await repo.fetchSchemes();
          final apps = await repo.fetchMyApplications(memberId);
          return schemes.where((s) => apps.containsKey(s.id)).map((s) => _TrackingRow(s, apps[s.id]!)).toList();
        },
        builder: (context, rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(icon: Icons.timeline_rounded, message: "You haven't applied to any schemes yet");
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final row = rows[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padded: false,
                  child: AppListRow(
                    title: row.scheme.name,
                    subtitle: row.scheme.agency ?? '',
                    trailing: AppBadge(text: row.application.status, tone: _statusTones[row.application.status] ?? BadgeTone.neutral),
                    onTap: () => context.go(Paths.schemeDetail(row.scheme.id)),
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
