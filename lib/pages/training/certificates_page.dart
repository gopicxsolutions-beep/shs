import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/training.dart';
import '../../repositories/training_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class CertificatesPage extends StatelessWidget {
  const CertificatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final repo = TrainingRepository();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Certificates'),
      body: AppAsyncBuilder<List<Course>>(
        future: () => repo.fetchCertificates(memberId),
        builder: (context, courses) {
          if (courses.isEmpty) {
            return const AppEmptyState(icon: Icons.workspace_premium_rounded, message: 'No certificates earned yet — complete a course quiz to get one');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, i) {
              final c = courses[i];
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
                          Text(c.topic, style: AppTheme.sans(11, color: Neutral.c500)),
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
