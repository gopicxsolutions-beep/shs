import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/announcement.dart';
import 'package:shg_saathi/models/payment.dart';
import 'package:shg_saathi/models/shg.dart';
import 'package:shg_saathi/models/shg_join_request.dart';
import 'package:shg_saathi/models/support.dart';

/// Regression coverage for round 63's timezone fix: `Announcement`,
/// `Payment`, `ShgDocument`, `ShgJoinRequest`, `SupportTicket`, and
/// `SupportMessage` all parse a `timestamptz` (UTC) column and call
/// `.toLocal()` right after `DateTime.parse()`, so the date-only
/// `DateFormat` calls at their real display sites (announcements home/
/// detail, payments history, SHG documents, join-request review, support
/// tickets/chat) never show the wrong calendar day.
///
/// Concrete bug this guards against (documented in
/// docs/DEVELOPMENT_PROGRESS.md, round 63): a record created at 2:00 AM IST
/// on 21 July is stored as `2026-07-20T20:30:00Z` (UTC) — parsing that
/// string WITHOUT `.toLocal()` and handing it to a date-only formatter
/// shows "20 Jul" instead of the correct "21 Jul". This is a real, ~5.5
/// hour daily window (local midnight to 5:29 AM IST), not a hypothetical
/// edge case. `.toLocal()` is exactly the kind of one-call fix that's easy
/// to silently drop in a future unrelated edit to these `fromMap`
/// factories, so each one is pinned down here directly.
///
/// Each case is checked two ways:
///  1. Timezone-independent (holds under any `flutter test` runner
///     timezone): the parsed value's *instant* must equal the source UTC
///     instant, and `isUtc` must be `false` (proof `.toLocal()` actually
///     ran — a UTC `DateTime` stays `isUtc: true` until converted).
///  2. The concrete calendar-day crossing from the bug report above, which
///     additionally requires the runner to be in a positive-UTC-offset
///     timezone (true for this project's dev/CI environment, and the only
///     timezone (IST) this app is ever actually deployed in).
void main() {
  const utcRaw = '2026-07-20T20:30:00Z'; // 2:00 AM IST on 21 July
  final utcInstant = DateTime.parse(utcRaw);
  final inPositiveOffsetZone = DateTime.now().timeZoneOffset.inMinutes > 0;

  void expectConvertedCorrectly(DateTime parsed) {
    expect(parsed.isUtc, isFalse, reason: '.toLocal() must have been called — a UTC DateTime stays isUtc:true otherwise');
    expect(parsed.isAtSameMomentAs(utcInstant), isTrue, reason: 'conversion must preserve the same instant, only change its representation');
    if (inPositiveOffsetZone) {
      expect(parsed.year, 2026);
      expect(parsed.month, 7);
      expect(parsed.day, 21, reason: '20:30 UTC on 20 July must land on 21 July local time in a positive-UTC-offset zone (e.g. IST) — the exact bug round 63 fixed');
    }
  }

  group('timestamptz -> local conversion at the fromMap boundary (round 63 fix)', () {
    test('Announcement.fromMap converts created_at', () {
      final a = Announcement.fromMap({
        'id': 'a1',
        'shg_id': 'shg1',
        'title': 'Test',
        'body': null,
        'category': 'Circular',
        'created_at': utcRaw,
      });
      expectConvertedCorrectly(a.createdAt);
    });

    test('Payment.fromMap converts created_at', () {
      final p = Payment.fromMap({
        'id': 'p1',
        'amount': 500,
        'mode': 'UPI',
        'reference': null,
        'status': 'success',
        'created_at': utcRaw,
      });
      expectConvertedCorrectly(p.createdAt);
    });

    test('ShgDocument.fromMap converts created_at', () {
      final d = ShgDocument.fromMap({
        'id': 'd1',
        'name': 'passbook.pdf',
        'type': 'pdf',
        'size': '1.2MB',
        'created_at': utcRaw,
      });
      expectConvertedCorrectly(d.createdAt);
    });

    test('ShgJoinRequest.fromMap converts requested_at', () {
      final r = ShgJoinRequest.fromMap({
        'id': 'r1',
        'member_id': 'm1',
        'shg_id': 'shg1',
        'status': 'pending',
        'requested_at': utcRaw,
      });
      expectConvertedCorrectly(r.requestedAt);
    });

    test('SupportTicket.fromMap converts created_at', () {
      final t = SupportTicket.fromMap({
        'id': 't1',
        'member_id': 'm1',
        'subject': 'Help',
        'description': null,
        'status': 'open',
        'created_at': utcRaw,
      });
      expectConvertedCorrectly(t.createdAt);
    });

    test('SupportMessage.fromMap converts created_at', () {
      final msg = SupportMessage.fromMap({
        'id': 'msg1',
        'ticket_id': 't1',
        'sender_id': 'm1',
        'body': 'hello',
        'created_at': utcRaw,
      });
      expectConvertedCorrectly(msg.createdAt);
    });
  });
}
