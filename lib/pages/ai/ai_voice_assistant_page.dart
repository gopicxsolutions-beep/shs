import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/types.dart';
import '../../repositories/announcement_repository.dart';
import '../../repositories/loan_repository.dart';
import '../../repositories/savings_repository.dart';
import '../../routes/paths.dart';
import '../../services/voice_recognition_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';

enum _AssistantState { idle, listening, thinking, answered }

const _languageLabels = <Language, String>{Language.te: 'తెలుగు', Language.hi: 'हिंदी', Language.en: 'English'};

/// The spec's "AI Voice Assistant" — distinct from Support's generic Voice
/// Support (`support_voice_page.dart`, free-form FAQ Q&A). This assistant
/// recognizes a small fixed set of commands in Telugu/Hindi/English (via
/// [MockVoiceRecognitionService], a placeholder for a real STT engine —
/// see docs/DEVELOPMENT_PROGRESS.md's "External API abstraction plan") and
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
  final VoiceRecognitionService _service = MockVoiceRecognitionService();
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
      final answer = await _resolve(command.intent, memberId, shgId);
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _state = _AssistantState.answered;
      });

      if (command.intent == VoiceIntent.addSavings && mounted) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) context.go(Paths.savingsEntry);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _answer = 'Sorry, something went wrong. Please try again.';
        _state = _AssistantState.answered;
      });
    }
  }

  Future<String> _resolve(VoiceIntent intent, String? memberId, String? shgId) async {
    switch (intent) {
      case VoiceIntent.loanDetails:
        final loans = await LoanRepository().fetchForMember(memberId);
        if (loans.isEmpty) return 'You have no loans on record.';
        final active = loans.where((l) => l.status == 'active' || l.status == 'overdue');
        if (active.isEmpty) return 'You have no active loans out of ${loans.length} on record.';
        final l = active.first;
        return '${l.purpose}: ₹${l.amount} loan, ₹${l.outstanding} still outstanding.';
      case VoiceIntent.savingsThisMonth:
        final entries = await SavingsRepository().fetchForMember(memberId);
        final now = DateTime.now();
        final thisMonth = entries.where((e) => e.date.year == now.year && e.date.month == now.month).toList();
        final total = thisMonth.fold<num>(0, (s, e) => s + e.amount);
        return 'You have saved ₹$total this month across ${thisMonth.length} entr${thisMonth.length == 1 ? 'y' : 'ies'}.';
      case VoiceIntent.readAnnouncements:
        final announcements = await AnnouncementRepository().fetchForShg(shgId, memberId);
        if (announcements.isEmpty) return 'You have no announcements.';
        return announcements.take(2).map((a) => a.title).join('. ');
      case VoiceIntent.addSavings:
        return 'Opening the savings entry form for you.';
      case VoiceIntent.unknown:
        return "Sorry, I didn't understand that.";
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
    final busy = _state == _AssistantState.listening || _state == _AssistantState.thinking;

    return Scaffold(
      appBar: const PageHeader(title: 'Voice Assistant'),
      body: ListView(
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
                  onSelected: busy ? null : (_) => setState(() => _language = l),
                  selectedColor: Brand.c50,
                  labelStyle: AppTheme.sans(12, weight: FontWeight.w600, color: selected ? Brand.c700 : Neutral.c600),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: selected ? Brand.c500 : Neutral.c200),
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
                  decoration: BoxDecoration(color: _state == _AssistantState.listening ? Accent.red50 : Accent.sky50, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(Icons.mic_rounded, size: 40, color: _state == _AssistantState.listening ? Accent.red600 : Accent.sky600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(label, style: AppTheme.sans(13, weight: FontWeight.w600, color: Neutral.c500))),
          if (_transcript != null) ...[
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.person_rounded, size: 14, color: Neutral.c400),
                    const SizedBox(width: 6),
                    Text('You said', style: AppTheme.sans(11, weight: FontWeight.w700, color: Neutral.c500)),
                  ]),
                  const SizedBox(height: 6),
                  Text(_transcript!, style: AppTheme.sans(15, weight: FontWeight.w600)),
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
                  Row(children: [
                    Icon(Icons.volume_up_rounded, size: 14, color: Accent.sky600),
                    const SizedBox(width: 6),
                    Text('Assistant', style: AppTheme.sans(11, weight: FontWeight.w700, color: Accent.sky600)),
                  ]),
                  const SizedBox(height: 6),
                  Text(_answer!, style: AppTheme.sans(14, color: Neutral.c700)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text('Try saying', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c500)),
          const SizedBox(height: 8),
          ..._examplesFor(_language).map((example) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      padded: false,
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Text('"$example"', style: AppTheme.sans(13, color: Neutral.c600))),
                    ),
                  )),
        ],
      ),
    );
  }

  List<String> _examplesFor(Language language) => switch (language) {
        Language.te => const ['నా రుణ వివరాలు చూపించు', 'ఈ నెల పొదుపు ఎంత?', 'నా ప్రకటనలు చదవండి'],
        Language.hi => const ['मेरे ऋण का विवरण दिखाओ', 'इस महीने कितनी बचत हुई?', 'मेरी घोषणाएं पढ़ो'],
        Language.en => const ['Show my loan details', 'How much savings this month?', 'Read my announcements'],
      };
}
