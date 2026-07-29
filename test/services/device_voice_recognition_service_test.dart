import 'package:flutter_test/flutter_test.dart';
import 'package:shg_saathi/models/types.dart';
import 'package:shg_saathi/services/device_voice_recognition_service.dart';

/// Regression coverage for a real bug found in the AI Voice Assistant: on
/// Flutter Web, `speech_to_text_web.dart`'s `locales()` can never report
/// anything (its `.lang` is only ever set by a PRIOR `listen()` call — a
/// chicken-and-egg problem specific to that platform's implementation), so
/// this app's locale resolution always saw an empty list there and fell
/// back to `null`, silently letting the browser recognize in its own
/// default language regardless of which language (Telugu/Hindi/English) the
/// member had actually picked in the page's own selector. `resolveVoiceLocaleId`
/// is the pure matching/fallback logic extracted out of
/// `DeviceVoiceRecognitionService._resolveLocaleId` specifically so this can
/// be tested without a fake `speech_to_text` plugin (the real plugin has no
/// mockable seam in this codebase).
void main() {
  group('resolveVoiceLocaleId', () {
    test('falls back to a direct te-IN code when the platform reports no locales at all (the Flutter Web case)', () {
      expect(resolveVoiceLocaleId(Language.te, []), 'te-IN');
    });

    test('falls back to a direct hi-IN code when the platform reports no locales at all', () {
      expect(resolveVoiceLocaleId(Language.hi, []), 'hi-IN');
    });

    test('falls back to a direct en-IN code when the platform reports no locales at all', () {
      expect(resolveVoiceLocaleId(Language.en, []), 'en-IN');
    });

    test('prefers an Indian-region match over a non-Indian one for the same language', () {
      expect(resolveVoiceLocaleId(Language.en, ['en-GB', 'en-IN', 'en-US']), 'en-IN');
    });

    test('falls back to any same-language match when no Indian-region variant exists', () {
      expect(resolveVoiceLocaleId(Language.te, ['en-US', 'te', 'hi-IN']), 'te');
    });

    test('matches case-insensitively', () {
      expect(resolveVoiceLocaleId(Language.hi, ['HI-IN']), 'HI-IN');
    });

    test('returns null (let the engine use its own default) when locales exist but none match the requested language', () {
      expect(resolveVoiceLocaleId(Language.te, ['en-US', 'hi-IN']), isNull);
    });

    // Gap-hunt iteration 28 (dogfooding round): a bare `startsWith(code)`
    // on the 2-letter code, with no subtag-boundary check, false-positive
    // matched an unrelated language whose primary subtag merely starts with
    // the same two letters — e.g. Tetum (`tet-TL`) against Telugu ('te'),
    // or Hiligaynon (`hil-PH`) against Hindi ('hi'). A device reporting one
    // of these would silently recognize in the wrong language with no error
    // at all, worse than the empty-list case above (which at least fails
    // in a handled way).
    test('does not false-positive-match an unrelated language sharing the same 2-letter prefix (tet-TL vs te)', () {
      expect(resolveVoiceLocaleId(Language.te, ['tet-TL']), isNull);
    });

    test('does not false-positive-match an unrelated language sharing the same 2-letter prefix (hil-PH vs hi)', () {
      expect(resolveVoiceLocaleId(Language.hi, ['hil-PH']), isNull);
    });

    test('still matches the real language when both a false-positive-prefix locale and a genuine one are present', () {
      expect(resolveVoiceLocaleId(Language.te, ['tet-TL', 'te-IN']), 'te-IN');
    });
  });

  group('isUnavailableVoiceError', () {
    test('classifies mic-permission denial as unavailable', () {
      expect(isUnavailableVoiceError('not-allowed'), isTrue);
    });

    test('classifies missing mic hardware as unavailable', () {
      expect(isUnavailableVoiceError('audio-capture'), isTrue);
    });

    test('classifies no-recognition-service as unavailable', () {
      expect(isUnavailableVoiceError('service-not-allowed'), isTrue);
    });

    test('does not classify an ordinary no-speech outcome as unavailable', () {
      expect(isUnavailableVoiceError('no-speech'), isFalse);
    });

    test('does not classify a network hiccup as unavailable', () {
      expect(isUnavailableVoiceError('network'), isFalse);
    });

    test('does not classify a null errorMsg as unavailable', () {
      expect(isUnavailableVoiceError(null), isFalse);
    });
  });
}
