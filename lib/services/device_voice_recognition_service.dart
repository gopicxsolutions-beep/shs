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

  @override
  Future<RecognizedCommand> listen(Language language) async {
    if (!_available) {
      _available = await _stt.initialize();
    }
    if (!_available) {
      throw StateError('Speech recognition is not available on this device.');
    }

    final localeId = await _resolveLocaleId(language);
    final completer = Completer<String>();

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
