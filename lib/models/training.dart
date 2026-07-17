/// Mirrors a row in `public.training_courses`.
class Course {
  final String id;
  final String title;
  final String topic;
  final String format; // Video | PDF | Audio
  final String? duration;

  const Course({required this.id, required this.title, required this.topic, required this.format, this.duration});

  factory Course.fromMap(Map<String, dynamic> map) => Course(
        id: map['id'] as String,
        title: map['title'] as String,
        topic: map['topic'] as String,
        format: map['format'] as String,
        duration: map['duration'] as String?,
      );
}

/// Mirrors a row in `public.course_progress` for one member/course pair.
class CourseProgress {
  final String courseId;
  final int progress;
  final bool certified;
  final DateTime? completedOn;

  const CourseProgress({required this.courseId, required this.progress, required this.certified, this.completedOn});

  factory CourseProgress.fromMap(Map<String, dynamic> map) => CourseProgress(
        courseId: map['course_id'] as String,
        progress: map['progress'] as int? ?? 0,
        certified: map['certified'] as bool? ?? false,
        completedOn: map['completed_on'] != null ? DateTime.parse(map['completed_on'] as String) : null,
      );
}
