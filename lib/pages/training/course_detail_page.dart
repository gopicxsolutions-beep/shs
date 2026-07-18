import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/training.dart';
import '../../repositories/training_repository.dart';
import '../../routes/paths.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/progress_bar.dart';

class _DetailData {
  final Course course;
  final CourseProgress? progress;
  const _DetailData(this.course, this.progress);
}

class CourseDetailPage extends StatefulWidget {
  final String courseId;
  const CourseDetailPage({super.key, required this.courseId});
  @override
  State<CourseDetailPage> createState() => _CourseDetailPageState();
}

class _CourseDetailPageState extends State<CourseDetailPage> {
  final _repo = TrainingRepository();
  final GlobalKey<AppAsyncBuilderState<_DetailData?>> _key = GlobalKey();
  bool _updating = false;

  Future<void> _continueCourse(int pct, String? memberId) async {
    setState(() => _updating = true);
    try {
      final next = (pct + 50).clamp(0, 100);
      await _repo.updateProgress(widget.courseId, memberId, next);
      if (mounted) _key.currentState?.reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save your progress. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: const PageHeader(title: 'Course Detail'),
      body: AppAsyncBuilder<_DetailData?>(
        key: _key,
        future: () async {
          final course = await _repo.fetchCourseById(widget.courseId);
          if (course == null) return null;
          final progress = await _repo.fetchMyProgress(memberId);
          return _DetailData(course, progress[widget.courseId]);
        },
        builder: (context, data) {
          if (data == null) {
            return const AppEmptyState(icon: Icons.error_outline_rounded, message: 'This course could not be found');
          }
          final course = data.course;
          final pct = data.progress?.progress ?? 0;
          final certified = data.progress?.certified ?? false;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(course.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white))),
                      if (certified) const AppBadge(text: 'Certified', tone: BadgeTone.neutral),
                    ]),
                    const SizedBox(height: 6),
                    Text('${course.topic} · ${course.format} · ${course.duration ?? ''}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                    const SizedBox(height: 12),
                    AppProgressBar(value: pct, tone: ProgressTone.info),
                    const SizedBox(height: 4),
                    Text('$pct% complete', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (!certified) ...[
                AppButton(
                  label: _updating ? 'Saving…' : (pct == 0 ? 'Start Course' : 'Continue'),
                  fullWidth: true,
                  size: ButtonSize.lg,
                  onPressed: !SupabaseService.isConfigured || _updating ? null : () => _continueCourse(pct, memberId),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'Take Quiz & Get Certified',
                  variant: ButtonVariant.outline,
                  fullWidth: true,
                  size: ButtonSize.lg,
                  onPressed: () => context.go(Paths.trainingQuiz(course.id)),
                ),
              ] else
                AppCard(
                  child: Row(children: [
                    Icon(Icons.workspace_premium_rounded, color: Gold.c600, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Text('You earned a certificate for this course!', style: AppTheme.sans(13, weight: FontWeight.w600))),
                  ]),
                ),
            ],
          );
        },
      ),
    );
  }
}
