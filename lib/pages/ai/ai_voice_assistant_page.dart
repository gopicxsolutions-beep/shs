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
import '../../widgets/async_state.dart' show isAuthExpiredError, isNetworkError;

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
  // Bumped on every _listen() call and captured locally as `requestId` so a
  // stale call (e.g. its 900ms pre-navigation delay for addSavings) can tell
  // it's been superseded by a newer tap and bail out instead of clobbering
  // the newer request's state or force-navigating out from under it — see
  // the guard comments in _listen().
  int _requestId = 0;

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
    // Without this, navigating away mid-listen (back button, bottom-nav tap)
    // left DeviceVoiceRecognitionService's native session running in the
    // background for up to its own 15s timeout with no owning widget left —
    // a real microphone/privacy leak, not just a wasted resource.
    _service.stop();
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
    // Captured once per call: the button is re-enabled as soon as _state
    // becomes `answered`, including during the 900ms addSavings delay below
    // — so a member who taps again quickly (well within that window) starts
    // a second, overlapping _listen() call in the same still-mounted State.
    // `mounted` alone can't distinguish "this call's own request" from "a
    // newer one that superseded it"; comparing against `_requestId` can.
    final requestId = ++_requestId;
    setState(() {
      _state = _AssistantState.listening;
      _transcript = null;
      _answer = null;
    });
    try {
      final command = await _service.listen(_language);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _transcript = command.transcript;
        _state = _AssistantState.thinking;
      });

      final appState = context.read<AppState>();
      final memberId = appState.profile?.id;
      final shgId = appState.profile?.shgId;
      final answer = await _resolve(context, command.intent, memberId, shgId);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _answer = answer;
        _state = _AssistantState.answered;
      });
      // The visual disclaimer banner is deliberately present on every AI
      // screen, every time (see its own doc comment) — but on this
      // voice-first surface it was never actually spoken, only printed as
      // small (11px) text, undermining the one safety caveat that exists
      // for the exact interaction mode (voice, plausibly because reading
      // is a barrier) where it matters most. Spoken after the answer, not
      // before, so the member hears her actual answer first.
      final disclaimer = lookupAppLocalizations(_localeFor(_language)).aiDisclaimer;
      unawaited(_speak('$answer. $disclaimer'));

      if (command.intent == VoiceIntent.addSavings) {
        await Future.delayed(const Duration(milliseconds: 900));
        // Re-checked after the delay, not just before it: a newer tap could
        // have started (and even finished) while this was waiting. Without
        // this, a member who asks "add a savings entry" and then quickly
        // asks something else gets yanked into the Savings Entry form out
        // from under whatever they just asked next.
        if (mounted && requestId == _requestId) context.go(Paths.savingsEntry);
      }
    } catch (e) {
      if (!mounted || requestId != _requestId) return;
      // Same isNetworkError-branched, localized message the rest of the app
      // uses (AppAsyncBuilder, otp_page.dart) — a dropped connection while
      // resolving the intent against a live repository looks different to
      // the member than "we couldn't understand that", so don't collapse
      // both into one hardcoded English string. Uses `_language` (this
      // page's own selector), not `AppLocalizations.of(context)`'s system
      // display language — same reasoning as `_resolve`'s doc comment.
      //
      // `DeviceVoiceRecognitionService.listen()`'s two distinct failure
      // modes (no usable recognizer at all vs. a session that just didn't
      // catch anything) previously both collapsed into this same generic
      // fallback, indistinguishable from any other failure — a member who
      // denied mic permission once saw an identical "Something went wrong"
      // on every later tap, with no way to learn the actual fix (enabling
      // the permission in system Settings) short of leaving the app.
      final l10n = lookupAppLocalizations(_localeFor(_language));
      setState(() {
        _answer = switch (e) {
          VoiceRecognitionUnavailableException() => l10n.voiceAssistantMicUnavailableError,
          VoiceRecognitionEmptyResultException() => l10n.voiceAssistantNoSpeechError,
          // Same gap as ai_advisor_chat_page.dart's identical fix: an
          // expired session during `_resolve()`'s repository calls (Loan/
          // Savings/AnnouncementRepository) previously fell through to the
          // generic message with no "sign in again" guidance, unlike every
          // other data screen (gap-hunt iteration 37).
          _ when isAuthExpiredError(e) => l10n.asyncErrorSessionExpired,
          _ when isNetworkError(e) => l10n.asyncErrorNetwork,
          _ => l10n.asyncErrorGeneric,
        };
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
    // Follows `_language` (this page's own selector), not the ambient
    // system display language — same reasoning as `_resolve`'s doc comment:
    // a member speaking Telugu into this page should see the whole voice
    // interaction, not just the resolved answer, in Telugu.
    final l10n = lookupAppLocalizations(_localeFor(_language));
    final label = switch (_state) {
      _AssistantState.idle => l10n.voiceAssistantTapToSpeak,
      _AssistantState.listening => l10n.voiceAssistantListening,
      _AssistantState.thinking => l10n.voiceAssistantThinking,
      _AssistantState.answered => l10n.voiceAssistantTapToAskAgain,
    };
    final busy =
        _state == _AssistantState.listening ||
        _state == _AssistantState.thinking;

    return Scaffold(
      appBar: PageHeader(title: l10n.voiceAssistantTitle),
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
                  // Was a plain Text with no live-region — this codebase's
                  // own established pattern for exactly this shape (see
                  // AppAsyncBuilder's doc comment) is `liveRegion: true` so
                  // a screen-reader user hears each state transition
                  // (Listening -> Thinking -> Answered) the instant it
                  // happens, not only if she happens to already be focused
                  // on this label.
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      label,
                      style: AppTheme.sans(
                        13,
                        weight: FontWeight.w600,
                        color: Neutral.c500,
                      ),
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
                              l10n.voiceAssistantYouSaid,
                              style: AppTheme.sans(
                                11,
                                weight: FontWeight.w700,
                                color: Neutral.c500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Was a plain Text with no live region — the state
                        // label above only announces "Listening/Thinking/
                        // Answered", not this card's actual content, so a
                        // screen-reader user had no way to hear what she
                        // was transcribed as saying without manually
                        // re-exploring the screen after each turn.
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _transcript!,
                            style: AppTheme.sans(15, weight: FontWeight.w600),
                          ),
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
                              l10n.voiceAssistantLabel,
                              style: AppTheme.sans(
                                11,
                                weight: FontWeight.w700,
                                color: Accent.sky600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Same fix as the "You said" card above — the state
                        // label doesn't announce the answer content itself,
                        // which matters most if TTS silently fails (see
                        // `_speak()`'s own doc comment on a missing voice
                        // pack for the member's selected language).
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _answer!,
                            style: AppTheme.sans(14, color: Neutral.c700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  l10n.voiceAssistantTrySaying,
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

  // Mirrors MockVoiceRecognitionService's per-language command lists 1:1
  // (all 4 intents, not just 3) — the addSavings phrase used to be missing
  // here even though it's this page's one voice-triggered-navigation
  // feature (see the class doc comment): a member had no way to discover
  // she could say it, since it was never suggested anywhere in the UI.
  List<String> _examplesFor(Language language) => switch (language) {
    Language.te => const [
      'నా రుణ వివరాలు చూపించు',
      'ఈ నెల పొదుపు ఎంత?',
      'నా ప్రకటనలు చదవండి',
      'పొదుపు నమోదు చేయండి',
    ],
    Language.hi => const [
      'मेरे ऋण का विवरण दिखाओ',
      'इस महीने कितनी बचत हुई?',
      'मेरी घोषणाएं पढ़ो',
      'बचत जोड़ें',
    ],
    Language.en => const [
      'Show my loan details',
      'How much savings this month?',
      'Read my announcements',
      'Add a savings entry',
    ],
  };
}
