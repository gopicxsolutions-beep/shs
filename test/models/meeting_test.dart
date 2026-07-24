import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/meeting.dart';

/// Regression coverage for `Meeting.hasPassed` — the fix for this session's
/// single most-repeated bug class (independently found and fixed at 6+ call
/// sites: `meeting_repository.dart`, the Meetings pages, `leader_dashboard.dart`
/// / `member_dashboard.dart`'s "next meeting" widgets, `trend_repository.dart`'s
/// attendance chart, and `ReportRepository`/`AnalyticsRepository`'s attendance
/// stats — see rounds 40-44 in docs/DEVELOPMENT_PROGRESS.md).
///
/// Root cause: nothing in the app ever calls `MeetingRepository.setStatus()`
/// (zero call sites), so a real meeting's `status` column stays `'upcoming'`
/// forever after creation, even long after its scheduled date has passed.
/// Any code that trusted `meeting.status` to know whether a meeting had
/// happened yet was permanently wrong. `hasPassed` is pure date-math (no
/// network/database dependency) comparing `date` against today, ignoring
/// `status` entirely — exactly the kind of cheap, dependency-free regression
/// guard this test locks in.
void main() {
  Meeting meetingOn(DateTime date, {String status = 'upcoming'}) => Meeting(
        id: 'm1',
        shgId: 'shg1',
        date: date,
        status: status,
      );

  group('Meeting.hasPassed', () {
    test('a meeting dated yesterday has passed', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final meeting = meetingOn(DateTime(yesterday.year, yesterday.month, yesterday.day));
      expect(meeting.hasPassed, isTrue);
    });

    test('a meeting dated today has NOT passed (same-day meetings have not happened yet)', () {
      final now = DateTime.now();
      final meeting = meetingOn(DateTime(now.year, now.month, now.day));
      expect(meeting.hasPassed, isFalse);
    });

    test('a meeting dated tomorrow has NOT passed', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final meeting = meetingOn(DateTime(tomorrow.year, tomorrow.month, tomorrow.day));
      expect(meeting.hasPassed, isFalse);
    });

    test('hasPassed is independent of the (permanently stale) status field', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final past = meetingOn(DateTime(yesterday.year, yesterday.month, yesterday.day), status: 'upcoming');
      expect(past.hasPassed, isTrue, reason: 'status stuck at "upcoming" must not stop hasPassed from reporting true once the date has gone by');

      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final future = meetingOn(DateTime(tomorrow.year, tomorrow.month, tomorrow.day), status: 'completed');
      expect(future.hasPassed, isFalse, reason: 'a stray "completed" status on a future-dated meeting must not make hasPassed report true');
    });

    test('a meeting from a month ago has passed', () {
      final now = DateTime.now();
      final aMonthAgo = DateTime(now.year, now.month - 1, now.day);
      final meeting = meetingOn(aMonthAgo);
      expect(meeting.hasPassed, isTrue);
    });
  });
}
