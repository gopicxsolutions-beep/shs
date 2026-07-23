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

  @override
  Future<String> transcribe() async {
    if (!_sttAvailable) {
      _sttAvailable = await _stt.initialize();
    }
    if (!_sttAvailable) {
      throw StateError('Speech recognition is not available on this device.');
    }

    final completer = Completer<String>();
    await _stt.listen(
      onResult: (result) {
        if (result.finalResult && !completer.isCompleted) completer.complete(result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      ),
    );

    String question;
    try {
      question = await completer.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      question = '';
    } finally {
      if (_stt.isListening) await _stt.stop();
    }

    if (question.trim().isEmpty) {
      throw StateError("Sorry, I couldn't hear anything. Please try again.");
    }
    return question;
  }

  @override
  Future<String> answer(String question) async {
    final answer = _matchFaq(question);
    unawaited(_speak(answer));
    return answer;
  }

  // Keyword-overlap match against the same FAQ content used by the (text)
  // FAQ page — not a mocked answer bank of its own. A real semantic-search
  // model would do better on paraphrased questions, but that needs a
  // vector index/embedding service this app doesn't have; word-overlap
  // against a small, fixed FAQ set is an honest, working middle ground.
  String _matchFaq(String question) {
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
      return "I don't have an answer for that yet. Try asking about savings, loans, your SHG grade, announcements, or support tickets — or raise a support ticket for a person to help.";
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
