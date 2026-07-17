import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/scheme.dart';
import '../../repositories/scheme_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_header.dart';

class SchemeDetailPage extends StatefulWidget {
  final String schemeId;
  const SchemeDetailPage({super.key, required this.schemeId});
  @override
  State<SchemeDetailPage> createState() => _SchemeDetailPageState();
}

class _SchemeDetailPageState extends State<SchemeDetailPage> {
  final _repo = SchemeRepository();
  final GlobalKey<AppAsyncBuilderState<SchemeApplication?>> _appKey = GlobalKey();
  bool _applying = false;

  Future<void> _apply(String? memberId) async {
    setState(() => _applying = true);
    try {
      await _repo.apply(schemeId: widget.schemeId, memberId: memberId);
      _appKey.currentState?.reload();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted')));
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Scheme Detail'),
      body: AppAsyncBuilder<Scheme?>(
        future: () => _repo.fetchSchemeById(widget.schemeId),
        builder: (context, scheme) {
          if (scheme == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This scheme could not be found');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(scheme.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    if (scheme.fullName != null) Text(scheme.fullName!, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 8),
                    if (scheme.agency != null) Text(scheme.agency!, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                    if (scheme.deadline != null) ...[
                      const SizedBox(height: 8),
                      Text('Deadline: ${DateFormat('dd MMM yyyy').format(scheme.deadline!)}', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (scheme.benefit != null) ...[
                const SectionHeader(title: 'Benefit'),
                AppCard(child: Text(scheme.benefit!, style: AppTheme.sans(13))),
                const SizedBox(height: 20),
              ],
              const SectionHeader(title: 'Eligibility'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: scheme.eligibility.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Icon(Icons.check_circle_rounded, size: 16, color: Brand.c500),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e, style: AppTheme.sans(12))),
                        ]),
                      )).toList(),
                ),
              ),
              const SizedBox(height: 20),
              AppAsyncBuilder<SchemeApplication?>(
                key: _appKey,
                future: () async {
                  final apps = await _repo.fetchMyApplications(memberId);
                  return apps[widget.schemeId];
                },
                builder: (context, app) {
                  if (app != null) {
                    return AppCard(child: Row(children: [
                      Text('Application status: ', style: AppTheme.sans(13)),
                      AppBadge(text: app.status, tone: BadgeTone.brand),
                    ]));
                  }
                  return AppButton(
                    label: _applying ? 'Submitting…' : 'Apply Now',
                    fullWidth: true,
                    size: ButtonSize.lg,
                    onPressed: !SupabaseService.isConfigured || _applying ? null : () => _apply(memberId),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
