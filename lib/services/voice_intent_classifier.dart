import '../models/types.dart';
import 'voice_recognition_service.dart';

/// Maps a raw speech-to-text transcript to a [VoiceIntent] via per-language
/// keyword matching. A real on-device STT engine returns arbitrary free
/// text ("how much did I save this month"), so something has to turn that
/// into [VoiceIntent.savingsThisMonth] — a small, fixed-domain keyword
/// classifier is the right scope for a bounded command set like this one
/// (5 intents, 3 languages), not a general-purpose NLU model.
class VoiceIntentClassifier {
  const VoiceIntentClassifier._();

  static VoiceIntent classify(String transcript, Language language) {
    final t = transcript.toLowerCase().trim();
    if (t.isEmpty) return VoiceIntent.unknown;
    final k = _keywords[language] ?? _keywords[Language.en]!;

    final mentionsSavings = k.savings.any(t.contains);
    final mentionsAddAction = k.addAction.any(t.contains);
    // "Add a savings entry" is checked before the more general "how much
    // have I saved" — both transcripts mention savings, but only one also
    // carries an action verb.
    if (mentionsSavings && mentionsAddAction) return VoiceIntent.addSavings;
    if (mentionsSavings) return VoiceIntent.savingsThisMonth;
    if (k.loan.any(t.contains)) return VoiceIntent.loanDetails;
    if (k.announcement.any(t.contains)) return VoiceIntent.readAnnouncements;
    return VoiceIntent.unknown;
  }
}

class _LanguageKeywords {
  final List<String> savings;
  final List<String> addAction;
  final List<String> loan;
  final List<String> announcement;
  const _LanguageKeywords({required this.savings, required this.addAction, required this.loan, required this.announcement});
}

const _keywords = <Language, _LanguageKeywords>{
  Language.en: _LanguageKeywords(
    savings: ['saving', 'savings', 'deposit', 'save'],
    addAction: ['add', 'record', 'enter', 'new', 'log'],
    loan: ['loan', 'emi', 'borrow', 'credit', 'due', 'installment'],
    announcement: ['announcement', 'announcements', 'notice', 'circular', 'update'],
  ),
  Language.hi: _LanguageKeywords(
    savings: ['बचत', 'जमा'],
    addAction: ['जोड़', 'दर्ज', 'नई', 'नया'],
    loan: ['ऋण', 'लोन', 'किस्त', 'उधार'],
    announcement: ['घोषणा', 'सूचना', 'नोटिस'],
  ),
  Language.te: _LanguageKeywords(
    savings: ['పొదుపు', 'పొదుపులు', 'జమ'],
    addAction: ['నమోదు', 'జోడించు', 'కొత్త'],
    loan: ['రుణ', 'లోన్', 'బాకీ'],
    announcement: ['ప్రకటన', 'ప్రకటనలు', 'నోటీసు'],
  ),
};
