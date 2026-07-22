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
  List<MeetingActionItem> _actionItems = [];
  bool _savingDecision = false;
  bool _savingActionItem = false;
  final _togglingItems = <String>{};

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
      if (mounted) {
        // In demo mode, reload() re-runs fetchLatestMinutes(), which
        // no-ops and returns null — that overwrote _decisions right back
        // to empty the instant it was added. Only reload where the fetch
        // will actually reflect what was just persisted.
        if (SupabaseService.isConfigured) {
          _minutesKey.currentState?.reload();
        } else {
          setState(() => _decisions = next);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo mode — not saved (connect Supabase to persist)')));
        }
      }
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
      final dueDate = DateTime.now().add(const Duration(days: 7));
      await _repo.addActionItem(widget.meetingId, text, dueDate: dueDate);
      if (mounted) {
        // Same issue as decisions: fetchActionItems() always returns an
        // empty list in demo mode, so reloading would immediately hide the
        // item that was just "added". Track it locally instead.
        if (SupabaseService.isConfigured) {
          _actionsKey.currentState?.reload();
        } else {
          setState(() => _actionItems = [
                ..._actionItems,
                MeetingActionItem(id: 'local-${DateTime.now().microsecondsSinceEpoch}', meetingId: widget.meetingId, task: text, dueDate: dueDate, done: false),
              ]);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo mode — not saved (connect Supabase to persist)')));
        }
      }
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
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final currentMemberId = appState.profile?.id;
    return Scaffold(
      appBar: const PageHeader(title: 'Minutes of Meeting'),
      // Unlike MeetingDetailPage (the only in-app link to this page), a
      // direct URL visit (e.g. #/app/meetings/does-not-exist/mom) never went
      // through that page's own not-found guard — fetchLatestMinutes/
      // fetchActionItems both just return empty results for a bogus
      // meetingId (no exception), so this page would silently render a
      // normal-looking, fully-interactive "Minutes of Meeting" screen for a
      // meeting that doesn't exist, letting a leader/staff account "add" a
      // decision or action item against it. Guarding on the meeting's own
      // existence first, mirroring every other :id detail page's
      // AppEmptyState pattern.
      body: AppAsyncBuilder<Meeting?>(
        future: () => _repo.fetchById(widget.meetingId),
        builder: (context, meeting) {
          if (meeting == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This meeting could not be found');
          }
          return _buildContent(context, isLeaderOrStaff, currentMemberId);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isLeaderOrStaff, String? currentMemberId) {
    return ListView(
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
                          icon: Icon(Icons.add_circle_rounded, color: !_savingDecision ? Brand.c600 : Neutral.c300),
                          onPressed: !_savingDecision ? _addDecision : null,
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
            future: () async {
              final items = await _repo.fetchActionItems(widget.meetingId);
              _actionItems = items;
              return items;
            },
            builder: (context, items) {
              return AppCard(
                padded: false,
                child: Column(
                  children: [
                    if (_actionItems.isEmpty)
                      Padding(padding: const EdgeInsets.all(16), child: Text('No action items yet', style: AppTheme.sans(12, color: Neutral.c400)))
                    else
                      ..._actionItems.map((item) {
                        // `meeting_action_items_write_related` (RLS) only lets
                        // the item's own owner, the SHG leader, or staff toggle
                        // it — any other member tapping this checkbox for
                        // someone else's item hit a silent RLS no-op (0 rows
                        // updated, no exception), so the checkbox visually
                        // flipped then snapped back with no explanation on the
                        // next reload.
                        final canToggle = isLeaderOrStaff || item.ownerId == currentMemberId;
                        // Guards against a rapid double-tap firing two
                        // concurrent `toggleActionItem` calls for the same
                        // row — the same double-submit shape already
                        // guarded against for the attendance `Switch` in
                        // `meeting_attendance_page.dart` via its `_updating`
                        // set, but this checkbox had no equivalent guard.
                        final isToggling = _togglingItems.contains(item.id);
                        return CheckboxListTile(
                            value: item.done,
                            activeColor: Brand.c600,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              item.task,
                              style: AppTheme.sans(13, weight: FontWeight.w600).copyWith(decoration: item.done ? TextDecoration.lineThrough : null),
                            ),
                            subtitle: item.dueDate != null ? Text('Due ${DateFormat('dd MMM yyyy').format(item.dueDate!)}', style: AppTheme.sans(11, color: Neutral.c500)) : null,
                            onChanged: (!canToggle || isToggling) ? null : (v) async {
                              setState(() => _togglingItems.add(item.id));
                              try {
                                await _repo.toggleActionItem(item.id, v ?? false);
                                if (mounted) {
                                  if (SupabaseService.isConfigured) {
                                    _actionsKey.currentState?.reload();
                                  } else {
                                    setState(() {
                                      final idx = _actionItems.indexWhere((i) => i.id == item.id);
                                      if (idx != -1) {
                                        _actionItems[idx] = MeetingActionItem(
                                          id: item.id,
                                          meetingId: item.meetingId,
                                          task: item.task,
                                          ownerId: item.ownerId,
                                          ownerName: item.ownerName,
                                          dueDate: item.dueDate,
                                          done: v ?? false,
                                        );
                                      }
                                    });
                                  }
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update this action item. Please try again.')));
                                }
                              } finally {
                                if (mounted) setState(() => _togglingItems.remove(item.id));
                              }
                            },
                          );
                      }),
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
                            icon: Icon(Icons.add_circle_rounded, color: !_savingActionItem ? Brand.c600 : Neutral.c300),
                            onPressed: !_savingActionItem ? _addActionItem : null,
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
      );
  }
}
