import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/training.dart' as mock;
import '../models/training.dart';
import '../services/supabase_service.dart';

/// Backed by `public.training_courses` / `public.course_progress` when
/// Supabase is configured; falls back to `lib/data/training.dart`
/// otherwise. The course catalog is public reference data.
class TrainingRepository {
  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _live => SupabaseService.isConfigured;

  // Demo mode has no backing table, so passing a quiz would otherwise never
  // show as certified anywhere — track it here so it survives for the rest
  // of the session, mirroring AnnouncementRepository._locallyRead.
  static final Set<String> _locallyCertified = {};

  Future<List<Course>> fetchCourses() async {
    if (!_live) return mock.courses.map((c) => Course(id: c.id, title: c.title, topic: c.topic, format: c.format, duration: c.duration)).toList();
    final rows = await _client.from('training_courses').select().order('created_at');
    return (rows as List).map((r) => Course.fromMap(r as Map<String, dynamic>)).toList();
  }

  Future<Course?> fetchCourseById(String id) async {
    if (!_live) {
      final matches = mock.courses.where((c) => c.id == id);
      if (matches.isEmpty) return null;
      final c = matches.first;
      return Course(id: c.id, title: c.title, topic: c.topic, format: c.format, duration: c.duration);
    }
    final row = await _client.from('training_courses').select().eq('id', id).maybeSingle();
    return row == null ? null : Course.fromMap(row);
  }

  Future<Map<String, CourseProgress>> fetchMyProgress(String? memberId) async {
    if (!_live || memberId == null) {
      return {
        for (final c in mock.courses)
          c.id: _locallyCertified.contains(c.id)
              ? CourseProgress(courseId: c.id, progress: 100, certified: true)
              : CourseProgress(courseId: c.id, progress: c.progress, certified: c.certified),
      };
    }
    final rows = await _client.from('course_progress').select().eq('member_id', memberId);
    return {for (final r in rows as List) (r as Map<String, dynamic>)['course_id'] as String: CourseProgress.fromMap(r)};
  }

  Future<void> updateProgress(String courseId, String? memberId, int progress) async {
    if (!_live || memberId == null) return;
    await _client.from('course_progress').upsert({
      'course_id': courseId,
      'member_id': memberId,
      'progress': progress,
    }, onConflict: 'course_id,member_id');
  }

  /// Called after passing the quiz — marks the course complete + certified.
  Future<void> markCertified(String courseId, String? memberId) async {
    if (!_live) {
      _locallyCertified.add(courseId);
      return;
    }
    await _client.from('course_progress').upsert({
      'course_id': courseId,
      'member_id': memberId,
      'progress': 100,
      'certified': true,
      'completed_on': DateTime.now().toIso8601String().split('T').first,
    }, onConflict: 'course_id,member_id');
  }

  Future<List<Course>> fetchCertificates(String? memberId) async {
    final progress = await fetchMyProgress(memberId);
    final courses = await fetchCourses();
    return courses.where((c) => progress[c.id]?.certified == true).toList();
  }
}
