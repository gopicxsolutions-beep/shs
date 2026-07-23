/// Abstraction over a speech-to-text / text-to-speech provider.
/// [DeviceVoiceSupportService] (`device_voice_support_service.dart`) is the
/// live-mode implementation — real on-device recognition + synthesis via
/// `speech_to_text`/`flutter_tts`, no vendor API key needed;
/// [MockVoiceSupportService] is used in demo mode so the app stays fully
/// explorable with no microphone.
abstract class VoiceSupportService {
  /// Transcribes a recorded question into text.
  Future<String> transcribe();

  /// Answers a transcribed question, speaking the reply aloud as a
  /// side effect where the implementation supports it.
  Future<String> answer(String question);
}

/// Cycles through a small set of canned SHG questions/answers so the voice
/// support flow (record → transcribe → answer → "play") is fully wired and
/// testable without a live STT/TTS provider.
class MockVoiceSupportService implements VoiceSupportService {
  static const _pairs = [
    (
      'How do I add a savings entry for this week?',
      'Go to Savings from the home screen, tap "Add Entry", enter the amount and date, then submit. Your group leader can see it right away.',
    ),
    (
      'When is our next SHG meeting?',
      'Check the Meetings tab — your next scheduled meeting date and time is shown at the top, along with the agenda if your leader has added one.',
    ),
    (
      'How do I apply for a loan?',
      'Open Loans and tap "Apply". Fill in the amount and purpose, then submit — your leader will review and approve it from the same screen.',
    ),
  ];

  int _i = 0;

  @override
  Future<String> transcribe() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final q = _pairs[_i % _pairs.length].$1;
    return q;
  }

  @override
  Future<String> answer(String question) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final match = _pairs.firstWhere((p) => p.$1 == question, orElse: () => _pairs[_i % _pairs.length]);
    _i++;
    return match.$2;
  }
}
