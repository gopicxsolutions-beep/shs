import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/savings.dart';
import '../../repositories/savings_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/list_row.dart';

class SavingsHistoryPage extends StatefulWidget {
  const SavingsHistoryPage({super.key});
  @override
  State<SavingsHistoryPage> createState() => _SavingsHistoryPageState();
}

class _SavingsHistoryPageState extends State<SavingsHistoryPage> {
  final _repo = SavingsRepository();
  final _key = GlobalKey<AppAsyncBuilderState<List<SavingsEntry>>>();

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Savings History'),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await _key.currentState?.reload();
          } catch (_) {
            // The FutureBuilder inside AppAsyncBuilder already surfaces this
            // failure with its own retry UI — swallow it here so it isn't
            // also reported as an unhandled async exception by
            // RefreshIndicator's separate listener on the same future.
          }
        },
        child: AppAsyncBuilder<List<SavingsEntry>>(
          key: _key,
          future: () => _repo.fetchForMember(memberId),
          builder: (context, entries) {
            if (entries.isEmpty) {
              return ListView(children: const [AppEmptyState(icon: Icons.history_rounded, message: 'No savings history yet')]);
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final e = entries[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    padded: false,
                    child: AppListRow(
                      title: '${e.frequency} savings',
                      subtitle: '${DateFormat('dd MMM yyyy').format(e.date)} · ${e.mode}',
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('₹${e.amount}', style: AppTheme.sans(13, weight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          AppBadge(text: e.status, tone: e.status == 'verified' ? BadgeTone.success : BadgeTone.warning),
                        ],
                      ),
                      chevron: false,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
