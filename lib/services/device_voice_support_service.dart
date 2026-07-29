import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../data/support.dart' as mock;
import 'voice_support_service.dart';

/// Real on-device speech recognition + synthesis for Support's Voice
/// Support feature (distinct from the AI Voice Assistant's
/// [DeviceVoiceRecognitionService] — this one answers free-form FAQ-style
/// questions rather than recognizing a fixed intent set). Matches the
/// transcribed question against the same FAQ content shown on the FAQ page
/// (`mock.mockFaqs`) by keyword overlap, then speaks the answer back via
/// on-device text-to-speech.
class DeviceVoiceSupportService implements VoiceSupportService {
  final stt.SpeechToText _stt = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _sttAvailable = false;
  // Mirrors DeviceVoiceRecognitionService's _pendingCompleter — see that
  // class's onError doc comment for the full "why" (same package, same
  // silent-error-until-15s-timeout bug, same fix).
  Completer<String>? _pendingCompleter;

  @override
  Future<String> transcribe() async {
    if (!_sttAvailable) {
      _sttAvailable = await _stt.initialize(
        onError: (error) {
          final completer = _pendingCompleter;
          if (completer != null && !completer.isCompleted) completer.complete('');
        },
      );
    }
    if (!_sttAvailable) {
      throw const VoiceSupportUnavailableException();
    }

    final completer = Completer<String>();
    _pendingCompleter = completer;

    String question;
    try {
      // See DeviceVoiceRecognitionService.listen's identical fix — listen()
      // itself must be inside this try/finally, not before it, so a throw
      // here still clears _pendingCompleter and stops the native session.
      // Explicit, not left to whatever the device/browser happens to
      // default to: the FAQ bank this feature matches against (`mock.
      // mockFaqs`, `lib/data/support.dart`) and `_speak`'s own TTS locale
      // below are both English-only by design — leaving `localeId` unset
      // here meant recognition ran in whatever language the platform
      // defaulted to, which is a coincidence, not a guarantee, and gave a
      // member no reason to expect any particular language would work.
      // Pinning it makes the already-intended English-only scope an actual
      // deliberate choice instead of a silent, undocumented one.
      await _stt.listen(
        onResult: (result) {
          if (result.finalResult && !completer.isCompleted) completer.complete(result.recognizedWords);
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          localeId: 'en-IN',
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      question = await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      question = '';
    } finally {
      _pendingCompleter = null;
      if (_stt.isListening) await _stt.stop();
    }

    if (question.trim().isEmpty) {
      throw const VoiceSupportEmptyResultException();
    }
    return question;
  }

  @override
  Future<void> stop() async {
    final completer = _pendingCompleter;
    _pendingCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete('');
    if (_stt.isListening) await _stt.stop();
    try {
      await _tts.stop();
    } catch (_) {}
  }

  @override
  Future<String> answer(String question, {String? noMatchFallback}) async {
    final answer = _matchFaq(question, noMatchFallback);
    unawaited(_speak(answer));
    return answer;
  }

  // Keyword-overlap match against the same FAQ content used by the (text)
  // FAQ page — not a mocked answer bank of its own. A real semantic-search
  // model would do better on paraphrased questions, but that needs a
  // vector index/embedding service this app doesn't have; word-overlap
  // against a small, fixed FAQ set is an honest, working middle ground.
  String _matchFaq(String question, String? noMatchFallback) {
    final words = _significantWords(question);
    mock.MockFaq? best;
    var bestScore = 0;
    for (final faq in mock.mockFaqs) {
      final score = words.intersection(_significantWords(faq.question)).length;
      if (score > bestScore) {
        bestScore = score;
        best = faq;
      }
    }
    if (best == null || bestScore == 0) {
      // The fallback below is the last resort for a caller that didn't
      // pass a localized string (e.g. a future direct-service caller) —
      // `SupportVoicePage` always passes `l10n.supportVoiceNoMatchFallback`
      // in practice, so a member never actually sees this raw English copy.
      return noMatchFallback ?? "I don't have an answer for that yet. Try asking about savings, loans, your SHG grade, announcements, or support tickets — or raise a support ticket for a person to help.";
    }
    return best.answer;
  }

  Set<String> _significantWords(String text) => text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.length > 3).toSet();

  // FAQ content itself is English-only (see lib/data/support.dart) — this
  // speaks in English regardless of the app's display language, since
  // there's nothing to synthesize in another language yet. Playback
  // failure (e.g. no TTS engine installed) is swallowed: the answer is
  // always shown as text either way, so speech is a bonus, not a
  // requirement for this feature to work.
  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage('en-IN');
      await _tts.speak(text);
    } catch (_) {}
  }
}
