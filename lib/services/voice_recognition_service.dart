import '../models/types.dart';

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

/// Abstraction over a real speech-to-text engine with Telugu/Hindi/English
/// support. No real STT provider is wired yet — a production key would
/// swap [MockVoiceRecognitionService] for a real implementation of this
/// same interface without touching any call site. See
/// docs/DEVELOPMENT_PROGRESS.md's "External API abstraction plan".
abstract class VoiceRecognitionService {
  Future<RecognizedCommand> listen(Language language);
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
}
