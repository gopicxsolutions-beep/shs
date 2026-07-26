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
class DeviceVoiceRecognitionService implements VoiceRecognitionService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _available = false;
  // The current listen() call's completer, if any — set just before
  // _stt.listen() and cleared in its `finally`. `onError` below is
  // registered once (at first initialize()) but fires for every recognition
  // session afterward, so it needs a way to reach whichever attempt is
  // currently in flight; see the onError doc comment for why this matters.
  Completer<String>? _pendingCompleter;

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
        onError: (error) {
          final completer = _pendingCompleter;
          if (completer != null && !completer.isCompleted) completer.complete('');
        },
      );
    }
    if (!_available) {
      throw StateError('Speech recognition is not available on this device.');
    }

    final localeId = await _resolveLocaleId(language);
    final completer = Completer<String>();
    _pendingCompleter = completer;

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

    String transcript;
    try {
      transcript = await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      transcript = '';
    } finally {
      _pendingCompleter = null;
      if (_stt.isListening) await _stt.stop();
    }

    if (transcript.trim().isEmpty) {
      throw StateError("Sorry, I couldn't hear anything. Please try again.");
    }
    return RecognizedCommand(transcript: transcript, intent: VoiceIntentClassifier.classify(transcript, language));
  }

  // speech_to_text's locale identifiers mirror whatever the platform's
  // installed recognizers report (format varies by OS/version), so this
  // matches by language-code prefix against the device's own reported list
  // rather than guessing a fixed "xx-YY" string that might not exist on
  // this particular device. Returning null lets the engine fall back to
  // its own default when no match is found, instead of failing outright.
  Future<String?> _resolveLocaleId(Language language) async {
    final code = switch (language) {
      Language.te => 'te',
      Language.hi => 'hi',
      Language.en => 'en',
    };
    final locales = await _stt.locales();
    for (final preferIndianRegion in [true, false]) {
      for (final l in locales) {
        final id = l.localeId.toLowerCase();
        if (id.startsWith(code) && (!preferIndianRegion || id.contains('in'))) return l.localeId;
      }
    }
    return null;
  }
}
