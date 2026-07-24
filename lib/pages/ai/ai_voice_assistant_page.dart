import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/types.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/loan_repository.dart';
import '../../repositories/savings_repository.dart';
import '../../routes/paths.dart';
import '../../services/device_voice_recognition_service.dart';
import '../../services/supabase_service.dart';
import '../../services/voice_recognition_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/ai_disclaimer_banner.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart' show isNetworkError;

enum _AssistantState { idle, listening, thinking, answered }

const _languageLabels = <Language, String>{
  Language.te: 'తెలుగు',
  Language.hi: 'हिंदी',
  Language.en: 'English',
};

// Mirrors main.dart's `_localeFor` (not shared — that one maps
// `AppState.language` for the whole app's `MaterialApp.locale`; this one
// maps this page's own local `_language` selector, a deliberately
// independent concept, see `_resolve`'s doc comment).
Locale _localeFor(Language language) => switch (language) {
  Language.te => const Locale('te'),
  Language.hi => const Locale('hi'),
  Language.en => const Locale('en'),
};

/// The spec's "AI Voice Assistant" — distinct from Support's generic Voice
/// Support (`support_voice_page.dart`, free-form FAQ Q&A). This assistant
/// recognizes a small fixed set of commands in Telugu/Hindi/English (via
/// [DeviceVoiceRecognitionService] in live mode — real on-device speech
/// recognition, no vendor API key needed; [MockVoiceRecognitionService] in
/// demo mode, so the app stays fully explorable with no microphone) and
/// resolves each against the member's *real* data (loans, savings,
/// announcements) rather than a canned answer, plus demonstrates
/// voice-triggered form navigation ("fill forms through voice" from the
/// spec — real dictation into form fields isn't feasible without a live
/// STT engine, so this is scoped to voice-triggered navigation into the
/// form, ready for input).
class AiVoiceAssistantPage extends StatefulWidget {
  const AiVoiceAssistantPage({super.key});
  @override
  State<AiVoiceAssistantPage> createState() => _AiVoiceAssistantPageState();
}

class _AiVoiceAssistantPageState extends State<AiVoiceAssistantPage> {
  final VoiceRecognitionService _service = SupabaseService.isConfigured ? DeviceVoiceRecognitionService() : MockVoiceRecognitionService();
  final FlutterTts _tts = FlutterTts();
  _AssistantState _state = _AssistantState.idle;
  late Language _language;
  String? _transcript;
  String? _answer;

  @override
  void initState() {
    super.initState();
    // Defaults to the member's actual app language instead of always
    // opening on Telugu regardless of their real preference.
    _language = context.read<AppState>().language;
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  // Speaks the answer aloud in `_language` (this page's own selector, not
  // the app's system display language — see `_resolve`'s doc comment for
  // why those are deliberately independent). Swallowed on failure: not
  // every device has a TTS voice installed for every language, and the
  // answer is always shown as text regardless, so speech is a bonus, not a
  // requirement for this feature to work.
  Future<void> _speak(String text) async {
    try {
      final locale = switch (_language) {
        Language.te => 'te-IN',
        Language.hi => 'hi-IN',
        Language.en => 'en-IN',
      };
      final available = await _tts.isLanguageAvailable(locale);
      if (available != true) return;
      await _tts.setLanguage(locale);
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> _listen() async {
    setState(() {
      _state = _AssistantState.listening;
      _transcript = null;
      _answer = null;
    });
    try {
      final command = await _service.listen(_language);
      if (!mounted) return;
      setState(() {
        _transcript = command.transcript;
        _state = _AssistantState.thinking;
      });

      final appState = context.read<AppState>();
      final memberId = appState.profile?.id;
      final shgId = appState.profile?.shgId;
      final answer = await _resolve(context, command.intent, memberId, shgId);
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _state = _AssistantState.answered;
      });
      unawaited(_speak(answer));

      if (command.intent == VoiceIntent.addSavings && mounted) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) context.go(Paths.savingsEntry);
      }
    } catch (e) {
      if (!mounted) return;
      // Same isNetworkError-branched, localized message the rest of the app
      // uses (AppAsyncBuilder, otp_page.dart) — a dropped connection while
      // resolving the intent against a live repository looks different to
      // the member than "we couldn't understand that", so don't collapse
      // both into one hardcoded English string. Uses `_language` (this
      // page's own selector), not `AppLocalizations.of(context)`'s system
      // display language — same reasoning as `_resolve`'s doc comment.
      final l10n = lookupAppLocalizations(_localeFor(_language));
      setState(() {
        _answer = isNetworkError(e)
            ? l10n.asyncErrorNetwork
            : l10n.asyncErrorGeneric;
        _state = _AssistantState.answered;
      });
    }
  }

  Future<String> _resolve(
    BuildContext context,
    VoiceIntent intent,
    String? memberId,
    String? shgId,
  ) async {
    // `AppLocalizations.of(context)` would answer in the app's SYSTEM
    // display language (AppState.language, via MaterialApp's `locale:`) —
    // wrong here, since this page has its own independent language
    // ChoiceChip (`_language`) letting a member ask in a different
    // language than their system display setting, the same way a real
    // voice assistant lets you speak in one language regardless of your
    // phone's UI language. Answering in the system language instead of
    // the language just spoken in would be confusing regardless of which
    // one happens to match — the answer must follow `_language`, not
    // `context`. `lookupAppLocalizations` (unlike `.of(context)`) takes an
    // explicit `Locale` instead of reading the ambient one.
    final l10n = lookupAppLocalizations(_localeFor(_language));
    switch (intent) {
      case VoiceIntent.loanDetails:
        final loans = await LoanRepository().fetchForMember(memberId);
        if (loans.isEmpty) return l10n.voiceNoLoans;
        final active = loans.where(
          (l) => l.status == 'active' || l.status == 'overdue',
        );
        if (active.isEmpty) return l10n.voiceNoActiveLoans(loans.length);
        final l = active.first;
        return l10n.voiceLoanActive(
          l.purpose,
          NumberFormat('#,##,##0', 'en_IN').format(l.amount),
          NumberFormat('#,##,##0', 'en_IN').format(l.outstanding),
        );
      case VoiceIntent.savingsThisMonth:
        final entries = await SavingsRepository().fetchForMember(memberId);
        final now = DateTime.now();
        final thisMonth = entries
            .where((e) => e.date.year == now.year && e.date.month == now.month)
            .toList();
        final total = thisMonth.fold<num>(0, (s, e) => s + e.amount);
        return l10n.voiceSavingsThisMonth(
          NumberFormat('#,##,##0', 'en_IN').format(total),
          thisMonth.length,
        );
      case VoiceIntent.readAnnouncements:
        final announcements = await AnnouncementRepository().fetchForShg(
          shgId,
          memberId,
        );
        if (announcements.isEmpty) return l10n.voiceNoAnnouncements;
        return announcements.take(2).map((a) => a.title).join('. ');
      case VoiceIntent.addSavings:
        return l10n.voiceOpeningSavingsForm;
      case VoiceIntent.unknown:
        return l10n.voiceUnknownCommand;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_state) {
      _AssistantState.idle => 'Tap to speak a command',
      _AssistantState.listening => 'Listening…',
      _AssistantState.thinking => 'Finding an answer…',
      _AssistantState.answered => 'Tap to ask again',
    };
    final busy =
        _state == _AssistantState.listening ||
        _state == _AssistantState.thinking;

    return Scaffold(
      appBar: const PageHeader(title: 'Voice Assistant'),
      body: Column(
        children: [
          const AiDisclaimerBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                Center(
                  child: Wrap(
                    spacing: 8,
                    children: Language.values.map((l) {
                      final selected = l == _language;
                      return ChoiceChip(
                        label: Text(_languageLabels[l]!),
                        selected: selected,
                        onSelected: busy
                            ? null
                            : (_) => setState(() => _language = l),
                        selectedColor: Brand.c50,
                        labelStyle: AppTheme.sans(
                          12,
                          weight: FontWeight.w600,
                          color: selected ? Brand.c700 : Neutral.c600,
                        ),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected ? Brand.c500 : Neutral.c200,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Tooltip(
                    message: label,
                    child: InkWell(
                      onTap: busy ? null : _listen,
                      borderRadius: BorderRadius.circular(48),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: _state == _AssistantState.listening
                              ? Accent.red50
                              : Accent.sky50,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.mic_rounded,
                          size: 40,
                          color: _state == _AssistantState.listening
                              ? Accent.red600
                              : Accent.sky600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    label,
                    style: AppTheme.sans(
                      13,
                      weight: FontWeight.w600,
                      color: Neutral.c500,
                    ),
                  ),
                ),
                if (_transcript != null) ...[
                  const SizedBox(height: 24),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 14,
                              color: Neutral.c400,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'You said',
                              style: AppTheme.sans(
                                11,
                                weight: FontWeight.w700,
                                color: Neutral.c500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _transcript!,
                          style: AppTheme.sans(15, weight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_answer != null) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    color: Accent.sky50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.volume_up_rounded,
                              size: 14,
                              color: Accent.sky600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Assistant',
                              style: AppTheme.sans(
                                11,
                                weight: FontWeight.w700,
                                color: Accent.sky600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _answer!,
                          style: AppTheme.sans(14, color: Neutral.c700),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Try saying',
                  style: AppTheme.sans(
                    12,
                    weight: FontWeight.w700,
                    color: Neutral.c500,
                  ),
                ),
                const SizedBox(height: 8),
                ..._examplesFor(_language).map(
                  (example) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padded: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          '"$example"',
                          style: AppTheme.sans(13, color: Neutral.c600),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _examplesFor(Language language) => switch (language) {
    Language.te => const [
      'నా రుణ వివరాలు చూపించు',
      'ఈ నెల పొదుపు ఎంత?',
      'నా ప్రకటనలు చదవండి',
    ],
    Language.hi => const [
      'मेरे ऋण का विवरण दिखाओ',
      'इस महीने कितनी बचत हुई?',
      'मेरी घोषणाएं पढ़ो',
    ],
    Language.en => const [
      'Show my loan details',
      'How much savings this month?',
      'Read my announcements',
    ],
  };
}
