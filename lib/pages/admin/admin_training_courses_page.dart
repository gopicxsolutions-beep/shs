import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/training.dart';
import '../../models/types.dart';
import '../../repositories/training_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

class AdminTrainingCoursesPage extends StatefulWidget {
  const AdminTrainingCoursesPage({super.key});
  @override
  State<AdminTrainingCoursesPage> createState() => _AdminTrainingCoursesPageState();
}

// DB CHECK-constrained (`training_courses.format`, migration 0001) — kept as
// literal codes, not translated, same convention as admin_schemes_page.dart's
// `_gradeOptions`.
const _formatOptions = ['Video', 'PDF', 'Audio'];

// Mirrors the training-videos bucket's own allow-list
// (0115_training_course_videos.sql): MP4, WebM, MOV.
const _allowedVideoExtensions = ['mp4', 'webm', 'mov'];
const _maxVideoBytes = 200 * 1024 * 1024; // mirrors the bucket's 200 MiB cap

String _contentTypeForVideo(String? extension) => switch (extension?.toLowerCase()) {
      'webm' => 'video/webm',
      'mov' => 'video/quicktime',
      _ => 'video/mp4',
    };

/// Before this page, the live `training_courses`/`quiz_questions` tables
/// were confirmed empty with no way to populate them except a direct SQL
/// insert — the entire Training module was non-functional in live mode
/// despite RLS (`training_courses_write_staff`/`quiz_questions_write_staff`)
/// already correctly permitting crp/clf/admin to write. Mirrors
/// `admin_schemes_page.dart`'s list + add/edit/delete dialog pattern.
/// Gated on `isStaff` (crp/clf/admin), not narrowed to `Role.admin` like
/// `admin_schemes_page.dart` — CRPs are this app's actual day-to-day
/// training content owners per the SRS's own role glossary ("monitors and
/// trains"), and RLS already permits them to write here, so limiting the UI
/// to admin-only would leave the RLS-granted capability just as unreachable
/// for CRP/CLF as it was before this page existed.
class _AdminTrainingCoursesPageState extends State<AdminTrainingCoursesPage> {
  final _repo = TrainingRepository();
  final GlobalKey<AppAsyncBuilderState<List<Course>>> _key = GlobalKey();
  final _title = TextEditingController();
  final _topic = TextEditingController();
  final _duration = TextEditingController();
  String _format = _formatOptions.first;
  bool _busy = false;

  // Video-attach state for the currently-open add/edit dialog. `_pickedVideo`
  // is a freshly-chosen file awaiting upload; `_existingVideoUrl` is the
  // course's already-attached video when editing; `_removeVideo` tracks an
  // explicit "remove" tap so a saved edit can clear a previously-attached
  // video rather than silently keeping it.
  PlatformFile? _pickedVideo;
  String? _existingVideoUrl;
  bool _removeVideo = false;

  @override
  void dispose() {
    _title.dispose();
    _topic.dispose();
    _duration.dispose();
    super.dispose();
  }

  List<Widget> _formFields(StateSetter setDialogState, AppLocalizations l10n) => [
        TextField(controller: _title, maxLength: 150, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminTrainingCoursesTitleHint)),
        const SizedBox(height: 12),
        TextField(controller: _topic, maxLength: 80, textInputAction: TextInputAction.next, decoration: InputDecoration(hintText: l10n.adminTrainingCoursesTopicHint)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _format,
          decoration: InputDecoration(labelText: l10n.adminTrainingCoursesFormatLabel),
          items: _formatOptions.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
          onChanged: (v) => setDialogState(() => _format = v ?? _formatOptions.first),
        ),
        const SizedBox(height: 12),
        TextField(controller: _duration, maxLength: 40, textInputAction: TextInputAction.done, decoration: InputDecoration(hintText: l10n.adminTrainingCoursesDurationHint)),
        const SizedBox(height: 12),
        _videoPickerRow(setDialogState, l10n),
      ];

  Widget _videoPickerRow(StateSetter setDialogState, AppLocalizations l10n) {
    final hasExisting = _existingVideoUrl != null && !_removeVideo;
    final label = _pickedVideo != null ? _pickedVideo!.name : (hasExisting ? l10n.adminTrainingCoursesVideoAttached : l10n.adminTrainingCoursesChooseVideo);
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: _allowedVideoExtensions, withData: true);
              final file = result?.files.isNotEmpty == true ? result!.files.first : null;
              if (file == null || file.bytes == null) return;
              if (file.size > _maxVideoBytes) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingCoursesVideoTooLarge)));
                return;
              }
              setDialogState(() {
                _pickedVideo = file;
                _removeVideo = false;
              });
            },
            icon: const Icon(Icons.video_file_outlined, size: 18),
            label: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (_pickedVideo != null || hasExisting) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: l10n.adminTrainingCoursesRemoveVideo,
            onPressed: () => setDialogState(() {
              _pickedVideo = null;
              _removeVideo = true;
            }),
          ),
        ],
      ],
    );
  }

  Future<void> _addCourse() async {
    final l10n = AppLocalizations.of(context)!;
    _title.clear();
    _topic.clear();
    _duration.clear();
    _format = _formatOptions.first;
    _pickedVideo = null;
    _existingVideoUrl = null;
    _removeVideo = false;
    final confirmed = await showDialog<bool>(
      context: context,
      // See shg_home_page.dart's identical fix for why: an accidental tap
      // just outside the dialog card otherwise silently discards every
      // field typed so far, indistinguishable from a real save failing.
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.adminTrainingCoursesAddDialogTitle),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: _formFields(setDialogState, l10n)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionAdd)),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingCoursesTitleRequiredError)));
      return;
    }
    setState(() => _busy = true);
    try {
      String? videoUrl;
      if (_pickedVideo != null && SupabaseService.isConfigured) {
        videoUrl = await _repo.uploadCourseVideo(bytes: _pickedVideo!.bytes!, fileName: _pickedVideo!.name, contentType: _contentTypeForVideo(_pickedVideo!.extension));
      }
      await _repo.createCourse(title: _title.text.trim(), topic: _topic.text.trim(), format: _format, duration: _duration.text.trim().isEmpty ? null : _duration.text.trim(), videoUrl: videoUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SupabaseService.isConfigured ? l10n.adminTrainingCoursesAddedMessage : l10n.adminTrainingCoursesDemoModeMessage)));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingCoursesAddErrorMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCourse(Course c) async {
    final l10n = AppLocalizations.of(context)!;
    _title.text = c.title;
    _topic.text = c.topic;
    _duration.text = c.duration ?? '';
    _format = _formatOptions.contains(c.format) ? c.format : _formatOptions.first;
    _pickedVideo = null;
    _existingVideoUrl = c.videoUrl;
    _removeVideo = false;
    final confirmed = await showDialog<bool>(
      context: context,
      // See shg_home_page.dart's identical fix for why: an accidental tap
      // just outside the dialog card otherwise silently discards every
      // field typed so far, indistinguishable from a real save failing.
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.adminTrainingCoursesEditDialogTitle),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: _formFields(setDialogState, l10n)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionSave)),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingCoursesTitleRequiredError)));
      return;
    }
    setState(() => _busy = true);
    try {
      var videoUrl = _removeVideo ? null : _existingVideoUrl;
      if (_pickedVideo != null && SupabaseService.isConfigured) {
        videoUrl = await _repo.uploadCourseVideo(bytes: _pickedVideo!.bytes!, fileName: _pickedVideo!.name, contentType: _contentTypeForVideo(_pickedVideo!.extension));
      }
      await _repo.updateCourse(c.id, title: _title.text.trim(), topic: _topic.text.trim(), format: _format, duration: _duration.text.trim().isEmpty ? null : _duration.text.trim(), videoUrl: videoUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SupabaseService.isConfigured ? l10n.adminTrainingCoursesUpdatedMessage : l10n.adminTrainingCoursesDemoModeMessage)));
        _key.currentState?.reload();
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingCoursesUpdateErrorMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCourse(Course c) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.adminTrainingCoursesDeleteDialogTitle),
        content: Text(l10n.adminTrainingCoursesDeleteDialogContent(c.title)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l10n.actionDelete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _repo.deleteCourse(c.id);
      if (mounted) {
        _key.currentState?.reload();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(SupabaseService.isConfigured ? l10n.adminTrainingCoursesDeletedMessage : l10n.adminTrainingCoursesDeleteDemoModeMessage)));
      }
    } on PostgrestException catch (e) {
      // '23503' = foreign-key violation — specifically the
      // `course_progress_course_id_fkey` RESTRICT (round 187's `0091`,
      // replacing the old CASCADE that used to silently destroy every
      // member's earned certification). Previously fell into the same
      // generic error toast as any other failure, giving the admin zero
      // indication WHY — she'd retry the identical action expecting a
      // transient failure, when this is actually a guaranteed, permanent
      // dead end for this course.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.code == '23503' ? l10n.adminTrainingCoursesDeleteHasProgressError : l10n.adminTrainingCoursesDeleteErrorMessage)));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.adminTrainingCoursesDeleteErrorMessage)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final role = context.watch<AppState>().user.role;
    final isStaff = const {Role.crp, Role.clf, Role.admin}.contains(role);

    return Scaffold(
      appBar: PageHeader(
        title: l10n.adminTrainingCoursesTitle,
        right: isStaff
            ? IconButton(
                icon: Icon(Icons.add_circle_rounded, color: !_busy ? Brand.c600 : Neutral.c300),
                onPressed: !_busy ? _addCourse : null,
                tooltip: l10n.adminTrainingCoursesAddCourseTooltip,
              )
            : null,
      ),
      body: AppAsyncBuilder<List<Course>>(
        key: _key,
        future: _repo.fetchCourses,
        builder: (context, courses) {
          if (courses.isEmpty) {
            return AppEmptyState(icon: Icons.school_rounded, message: l10n.adminTrainingCoursesEmptyState);
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: courses.length,
            itemBuilder: (context, i) {
              final c = courses[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => context.go(Paths.adminTrainingQuiz(c.id), extra: c.title),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.title, style: AppTheme.sans(13, weight: FontWeight.w700)),
                              Text('${c.topic} · ${c.format}${c.duration != null ? ' · ${c.duration}' : ''}', style: AppTheme.sans(11, color: Neutral.c500)),
                            ],
                          ),
                        ),
                      ),
                      if (isStaff) ...[
                        IconButton(
                          icon: Icon(Icons.quiz_outlined, color: !_busy ? Brand.c600 : Neutral.c300),
                          onPressed: !_busy ? () => context.go(Paths.adminTrainingQuiz(c.id), extra: c.title) : null,
                          tooltip: l10n.adminTrainingCoursesManageQuizTooltip(c.title),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: !_busy ? Brand.c600 : Neutral.c300),
                          onPressed: !_busy ? () => _editCourse(c) : null,
                          tooltip: l10n.adminTrainingCoursesEditTooltip(c.title),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: !_busy ? Accent.red500 : Neutral.c300),
                          onPressed: !_busy ? () => _deleteCourse(c) : null,
                          tooltip: l10n.adminTrainingCoursesDeleteTooltip(c.title),
                        ),
                      ],
                    ],
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
