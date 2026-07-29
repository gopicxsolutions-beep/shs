import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/types.dart';
import 'voice_intent_classifier.dart';
import 'voice_recognition_service.dart';

/// Real on-device speech recognition — Android `SpeechRecognizer` / iOS
/// `SFSpeechRecognizer` via the `speech_to_text` package. No cloud vendor
/// account or API key is needed: both platforms ship a built-in speech
/// engine, which is what this talks to directly. Recognized text is
/// classified into a [VoiceIntent] by [VoiceIntentClassifier].
///
/// Availability depends on the real device: the OS permission prompt,
/// whether a speech-recognition service is installed, and whether the
/// requested language has a recognizer installed all affect whether
/// [listen] succeeds — this is genuine device behavior, not a simulated
/// failure mode.
// speech_to_text's web `onError`/browser SpeechRecognition error codes that
// mean the recognizer itself can't be used at all (permission denied, no
// mic hardware, no recognition service available) — as opposed to a
// transient "listened but didn't catch anything" outcome. Standard Web
// Speech API error values per the spec, plus this package's own two
// synthetic ones raised from its web `initialize()` (`'not supported'` /
// `'speech_not_supported'`, see speech_to_text_web.dart) for completeness —
// those two are already caught by the `!_available` check below since they
// only ever fire before `_available` is set, but listing them here too
// costs nothing and documents the full set in one place.
const _unavailableErrorMessages = {
  'not-allowed',
  'service-not-allowed',
  'audio-capture',
  'not supported',
  'speech_not_supported',
};

/// Whether a `SpeechRecognitionError.errorMsg` means the recognizer can't be
/// used at all, vs. an ordinary no-match. Exposed as a top-level function
/// (rather than left as a private set-membership check) purely so a test can
/// exercise the classification directly without needing a fake `stt.SpeechToText`.
bool isUnavailableVoiceError(String? errorMsg) => _unavailableErrorMessages.contains(errorMsg);

/// Pure matching logic behind [DeviceVoiceRecognitionService._resolveLocaleId],
/// factored out so it's testable without a real/fake `speech_to_text` plugin:
/// given the language the member picked and the raw locale-id strings the
/// platform reports (empty on Flutter Web — see the doc comment on the call
/// site), returns which BCP-47 id to pass into `stt.listen()`.
String? resolveVoiceLocaleId(Language language, List<String> availableLocaleIds) {
  final code = switch (language) {
    Language.te => 'te',
    Language.hi => 'hi',
    Language.en => 'en',
  };
  // A bare `startsWith(code)` on the 2-letter language code (no subtag
  // boundary check) false-positive-matches any locale whose primary subtag
  // merely starts with the same two letters but is a different language
  // entirely — e.g. `tet-TL` (Tetum) or `teo-KE` (Teso) both start with
  // "te", as does `hil-PH` (Hiligaynon) with "hi". A real device reporting
  // one of these would silently pick the wrong recognizer language with no
  // error at all — worse than the empty-list fallback case above, which at
  // least fails in an expected, handled way. Splitting on the BCP-47
  // subtag delimiter and comparing the primary subtag exactly closes this.
  bool matchesLanguage(String id) => id.toLowerCase().split(RegExp('[-_]')).first == code;
  for (final preferIndianRegion in [true, false]) {
    for (final id in availableLocaleIds) {
      if (matchesLanguage(id) && (!preferIndianRegion || id.toLowerCase().contains('in'))) return id;
    }
  }
  if (availableLocaleIds.isEmpty) {
    return switch (language) {
      Language.te => 'te-IN',
      Language.hi => 'hi-IN',
      Language.en => 'en-IN',
    };
  }
  return null;
}

class DeviceVoiceRecognitionService implements VoiceRecognitionService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _available = false;
  // The current listen() call's completer, if any — set just before
  // _stt.listen() and cleared in its `finally`. `onError` below is
  // registered once (at first initialize()) but fires for every recognition
  // session afterward, so it needs a way to reach whichever attempt is
  // currently in flight; see the onError doc comment for why this matters.
  Completer<String>? _pendingCompleter;
  // Set by `onError` when the error it just saw means the recognizer is
  // unusable (mic permission denied, no mic hardware, no recognition
  // service) rather than merely "didn't catch anything this attempt" — see
  // the empty-transcript check below for why this needs to survive past the
  // completer resolving with '' (both outcomes complete the SAME completer
  // with the same empty string, since `onResult`'s type only carries text).
  bool _lastErrorUnavailable = false;

  @override
  Future<RecognizedCommand> listen(Language language) async {
    if (!_available) {
      _available = await _stt.initialize(
        // Without this, a real recognizer-side failure mid-attempt (no
        // speech detected, the recognizer briefly busy right after
        // initialize()'s permission/service-bind, a device-level timeout —
        // all legitimate, non-rare outcomes on a real phone) fires only
        // through this callback, which previously went nowhere: `listen()`
        // below only ever completes `completer` from `onResult`, so a
        // dropped error left the completer untouched until the blind 15s
        // timeout finally gave up — with the mic button disabled that whole
        // time (`busy` in ai_voice_assistant_page.dart). That silent 15s
        // dead-air-per-failed-attempt is what read as "the app needs 2-3
        // tries before it hears me": each failed attempt quietly burned 15
        // seconds before the member could even try again. Completing with
        // '' (not throwing here) reuses the exact same "couldn't hear
        // anything, please try again" path the timeout branch already
        // takes below, just reached immediately instead of after 15s.
        //
        // `_lastErrorUnavailable` additionally distinguishes WHICH empty
        // outcome this is: a denied mic permission or missing mic hardware
        // used to land on the exact same "Sorry, I couldn't hear anything.
        // Please try again." as a genuine silent room — telling a member to
        // retry something that literally cannot succeed until she goes into
        // her phone/browser Settings, with no hint that Settings is even
        // the problem. Found on the web platform specifically: a browser
        // permission denial fires `'not-allowed'` here on every subsequent
        // tap, forever, until she manually re-grants it outside the app.
        onError: (error) {
          _lastErrorUnavailable = isUnavailableVoiceError(error.errorMsg);
          final completer = _pendingCompleter;
          if (completer != null && !completer.isCompleted) completer.complete('');
        },
      );
    }
    if (!_available) {
      throw const VoiceRecognitionUnavailableException();
    }

    // `onError` above is registered ONCE for this instance's whole
    // lifetime, not per-`listen()` call, and the plugin gives it no id
    // correlating an error back to which attempt raised it — it just
    // resolves whatever `_pendingCompleter` happens to be set to at the
    // moment it fires. If a previous attempt's completer were still live
    // here, a late/delayed native error from THAT old attempt (e.g. web's
    // `SpeechRecognition.onerror` firing asynchronously just after a
    // `stop()` was already issued for it) could resolve THIS new attempt's
    // completer instead, silently discarding whatever real transcript this
    // attempt was about to produce. The page-level UI already disables the
    // mic button while an attempt is in flight, so this shouldn't normally
    // be reachable — but forcing a clean stop of any stray prior completer
    // first removes the overlap window entirely rather than relying only
    // on the caller never invoking `listen()` twice concurrently.
    if (_pendingCompleter != null) {
      await stop();
    }

    final localeId = await _resolveLocaleId(language);
    final completer = Completer<String>();
    _pendingCompleter = completer;
    _lastErrorUnavailable = false;

    String transcript;
    try {
      // `_stt.listen()` itself used to sit OUTSIDE this try/finally — if it
      // threw (a platform-channel error, or a session left half-open by a
      // page that navigated away mid-listen without calling stop(), see
      // this class's own [stop] doc comment), the exception propagated
      // without ever clearing `_pendingCompleter` or calling `_stt.stop()`,
      // leaving a completer that would never complete and a native session
      // with nothing left to stop it cleanly.
      await _stt.listen(
        onResult: (result) {
          if (result.finalResult && !completer.isCompleted) completer.complete(result.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.confirmation,
          localeId: localeId,
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      transcript = await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      transcript = '';
    } finally {
      _pendingCompleter = null;
      if (_stt.isListening) await _stt.stop();
    }

    if (transcript.trim().isEmpty) {
      if (_lastErrorUnavailable) throw const VoiceRecognitionUnavailableException();
      throw const VoiceRecognitionEmptyResultException();
    }
    return RecognizedCommand(transcript: transcript, intent: VoiceIntentClassifier.classify(transcript, language));
  }

  @override
  Future<void> stop() async {
    final completer = _pendingCompleter;
    _pendingCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete('');
    if (_stt.isListening) await _stt.stop();
  }

  // speech_to_text's locale identifiers mirror whatever the platform's
  // installed recognizers report (format varies by OS/version), so this
  // matches by language-code prefix against the device's own reported list
  // rather than guessing a fixed "xx-YY" string that might not exist on
  // this particular device.
  //
  // On Flutter Web specifically, `locales()` can never do this: the web
  // implementation's `locales()` just echoes back whatever `.lang` a PRIOR
  // `listen()` call already set on the browser's `SpeechRecognition` object
  // (see speech_to_text_web.dart) — before the very first `listen()` ever
  // runs, that's always empty, and `listen()` is the very thing this method
  // is called to set up in the first place. So on web this returned `[]`
  // on every call, every time, and the caller's fallback (a `null` localeId,
  // "let the engine use its own default") left the browser recognizing in
  // whatever language it defaults to — frequently English — completely
  // ignoring the member's actual language selection (Telugu/Hindi). A member
  // who picked Telugu and spoke Telugu into an English-default recognizer
  // would get silence/garbage every time: this read as "the voice assistant
  // doesn't work," when the real bug was that her language choice was being
  // thrown away. A real device's `locales()` always reports at least its
  // own system default (Android/iOS genuinely enumerate installed
  // recognizer languages), so an empty list is itself the reliable signal
  // that this platform's `locales()` isn't meaningful — falls back to a
  // direct, well-known BCP-47 regional code instead of giving up.
  Future<String?> _resolveLocaleId(Language language) async {
    final locales = await _stt.locales();
    return resolveVoiceLocaleId(language, locales.map((l) => l.localeId).toList());
  }
}
