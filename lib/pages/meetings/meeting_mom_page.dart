import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/meeting.dart';
import '../../models/types.dart';
import '../../repositories/meeting_repository.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/section_header.dart';

class MeetingMomPage extends StatefulWidget {
  final String meetingId;
  const MeetingMomPage({super.key, required this.meetingId});
  @override
  State<MeetingMomPage> createState() => _MeetingMomPageState();
}

class _MeetingMomPageState extends State<MeetingMomPage> {
  final _repo = MeetingRepository();
  final _decisionController = TextEditingController();
  final _taskController = TextEditingController();
  final GlobalKey<AppAsyncBuilderState<MeetingMinutes?>> _minutesKey = GlobalKey();
  final GlobalKey<AppAsyncBuilderState<List<MeetingActionItem>>> _actionsKey = GlobalKey();
  List<String> _decisions = [];
  bool _savingDecision = false;
  bool _savingActionItem = false;

  @override
  void dispose() {
    _decisionController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _addDecision() async {
    if (_savingDecision) return;
    final text = _decisionController.text.trim();
    if (text.isEmpty) return;
    setState(() => _savingDecision = true);
    final next = [..._decisions, text];
    _decisionController.clear();
    try {
      await _repo.saveMinutes(widget.meetingId, next);
      _decisions = next;
      _minutesKey.currentState?.reload();
    } catch (_) {
      if (mounted) {
        _decisionController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save this decision. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _savingDecision = false);
    }
  }

  Future<void> _addActionItem() async {
    if (_savingActionItem) return;
    final text = _taskController.text.trim();
    if (text.isEmpty) return;
    setState(() => _savingActionItem = true);
    _taskController.clear();
    try {
      await _repo.addActionItem(widget.meetingId, text, dueDate: DateTime.now().add(const Duration(days: 7)));
      if (mounted) _actionsKey.currentState?.reload();
    } catch (_) {
      if (mounted) {
        _taskController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save this action item. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _savingActionItem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLeaderOrStaff = context.watch<AppState>().user.role != Role.member;
    return Scaffold(
      appBar: const PageHeader(title: 'Minutes of Meeting'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(title: 'Decisions'),
          AppAsyncBuilder<MeetingMinutes?>(
            key: _minutesKey,
            future: () async {
              final m = await _repo.fetchLatestMinutes(widget.meetingId);
              _decisions = m?.decisions ?? [];
              return m;
            },
            builder: (context, minutes) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_decisions.isEmpty)
                      Text('No decisions recorded yet', style: AppTheme.sans(12, color: Neutral.c400))
                    else
                      ..._decisions.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${e.key + 1}. ', style: AppTheme.sans(13, weight: FontWeight.w700, color: Brand.c600)),
                              Expanded(child: Text(e.value, style: AppTheme.sans(13))),
                            ]),
                          )),
                    if (isLeaderOrStaff) ...[
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _decisionController,
                            style: AppTheme.sans(13),
                            maxLength: 300,
                            decoration: const InputDecoration(border: InputBorder.none, hintText: 'Add a decision…', counterText: ''),
                            onSubmitted: (_) => _addDecision(),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_rounded, color: SupabaseService.isConfigured && !_savingDecision ? Brand.c600 : Neutral.c300),
                          onPressed: SupabaseService.isConfigured && !_savingDecision ? _addDecision : null,
                          tooltip: 'Add decision',
                        ),
                      ]),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Action Items'),
          AppAsyncBuilder<List<MeetingActionItem>>(
            key: _actionsKey,
            future: () => _repo.fetchActionItems(widget.meetingId),
            builder: (context, items) {
              return AppCard(
                padded: false,
                child: Column(
                  children: [
                    if (items.isEmpty)
                      Padding(padding: const EdgeInsets.all(16), child: Text('No action items yet', style: AppTheme.sans(12, color: Neutral.c400)))
                    else
                      ...items.map((item) => CheckboxListTile(
                            value: item.done,
                            activeColor: Brand.c600,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              item.task,
                              style: AppTheme.sans(13, weight: FontWeight.w600).copyWith(decoration: item.done ? TextDecoration.lineThrough : null),
                            ),
                            subtitle: item.dueDate != null ? Text('Due ${DateFormat('dd MMM yyyy').format(item.dueDate!)}', style: AppTheme.sans(11, color: Neutral.c500)) : null,
                            onChanged: !SupabaseService.isConfigured
                                ? null
                                : (v) async {
                                    try {
                                      await _repo.toggleActionItem(item.id, v ?? false);
                                      if (mounted) _actionsKey.currentState?.reload();
                                    } catch (_) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this action item. Please try again.')));
                                      }
                                    }
                                  },
                          )),
                    if (isLeaderOrStaff)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                        child: Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _taskController,
                              style: AppTheme.sans(13),
                              maxLength: 300,
                              decoration: const InputDecoration(border: InputBorder.none, hintText: 'Add a task…', counterText: ''),
                              onSubmitted: (_) => _addActionItem(),
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.add_circle_rounded, color: SupabaseService.isConfigured && !_savingActionItem ? Brand.c600 : Neutral.c300),
                            onPressed: SupabaseService.isConfigured && !_savingActionItem ? _addActionItem : null,
                            tooltip: 'Add action item',
                          ),
                        ]),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
