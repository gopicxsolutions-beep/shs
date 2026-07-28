import '../models/types.dart';

/// Thrown by [DeviceVoiceRecognitionService.listen] when the device has no
/// usable speech recognizer — mic permission denied, no recognition service
/// installed, or the requested language has none. Distinct from
/// [VoiceRecognitionEmptyResultException] so the page can tell "nothing
/// will ever work here" (needs a permission/settings fix) apart from "that
/// one attempt didn't catch anything" (just try again) — collapsing both
/// into one generic error previously left a member who denied mic
/// permission once seeing an identical "Something went wrong" on every
/// later tap, with no path to the actual fix.
class VoiceRecognitionUnavailableException implements Exception {
  const VoiceRecognitionUnavailableException();
}

/// Thrown by [DeviceVoiceRecognitionService.listen] when a recognition
/// session completed with no usable transcript — silence, background
/// noise, or a recognizer-side hiccup (see that class's `onError` handling).
/// See [VoiceRecognitionUnavailableException]'s doc comment for why this is
/// a distinct type rather than reusing a generic error.
class VoiceRecognitionEmptyResultException implements Exception {
  const VoiceRecognitionEmptyResultException();
}

/// What the AI Voice Assistant recognized from a spoken command — distinct
/// from Support's generic Voice Support (`MockVoiceSupportService`), which
/// answers free-form FAQ-style questions with a canned response. This
/// service only recognizes a small fixed set of *intents*; the page then
/// resolves each intent against real repositories (loans/savings/
/// announcements), so the answer reflects the member's actual data.
enum VoiceIntent { loanDetails, savingsThisMonth, readAnnouncements, addSavings, unknown }

class RecognizedCommand {
  final String transcript;
  final VoiceIntent intent;
  const RecognizedCommand({required this.transcript, required this.intent});
}

/// Abstraction over a speech-to-text engine with Telugu/Hindi/English
/// support. [DeviceVoiceRecognitionService] (`device_voice_recognition_service.dart`)
/// is the live-mode implementation — real on-device recognition via the
/// `speech_to_text` package, no vendor API key needed; [MockVoiceRecognitionService]
/// is used in demo mode so the app stays fully explorable with no microphone.
abstract class VoiceRecognitionService {
  Future<RecognizedCommand> listen(Language language);

  /// Stops any in-flight recognition session immediately. Call this from a
  /// page's `dispose()` if the member navigates away mid-listen — without
  /// it, [DeviceVoiceRecognitionService]'s native session keeps the
  /// microphone open in the background for up to its own timeout with no
  /// owning widget left to receive the result.
  Future<void> stop();
}

/// Cycles through the spec's example commands (and their Hindi/English
/// equivalents) per language, so the listen → recognize → resolve flow is
/// fully wired and testable without a live STT engine.
class MockVoiceRecognitionService implements VoiceRecognitionService {
  static const _commandsByLanguage = <Language, List<(String, VoiceIntent)>>{
    Language.te: [
      ('నా రుణ వివరాలు చూపించు', VoiceIntent.loanDetails),
      ('ఈ నెల పొదుపు ఎంత?', VoiceIntent.savingsThisMonth),
      ('నా ప్రకటనలు చదవండి', VoiceIntent.readAnnouncements),
      ('పొదుపు నమోదు చేయండి', VoiceIntent.addSavings),
    ],
    Language.hi: [
      ('मेरे ऋण का विवरण दिखाओ', VoiceIntent.loanDetails),
      ('इस महीने कितनी बचत हुई?', VoiceIntent.savingsThisMonth),
      ('मेरी घोषणाएं पढ़ो', VoiceIntent.readAnnouncements),
      ('बचत जोड़ें', VoiceIntent.addSavings),
    ],
    Language.en: [
      ('Show my loan details', VoiceIntent.loanDetails),
      ('How much savings this month?', VoiceIntent.savingsThisMonth),
      ('Read my announcements', VoiceIntent.readAnnouncements),
      ('Add a savings entry', VoiceIntent.addSavings),
    ],
  };

  int _i = 0;

  @override
  Future<RecognizedCommand> listen(Language language) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final list = _commandsByLanguage[language] ?? _commandsByLanguage[Language.en]!;
    final (transcript, intent) = list[_i % list.length];
    _i++;
    return RecognizedCommand(transcript: transcript, intent: intent);
  }

  @override
  Future<void> stop() async {}
}
