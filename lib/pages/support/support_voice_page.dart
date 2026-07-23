import 'package:flutter/material.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../services/device_voice_support_service.dart';
import '../../services/supabase_service.dart';
import '../../services/voice_support_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';

enum _VoiceState { idle, listening, thinking, answered }

/// Voice support powered by [VoiceSupportService] — [DeviceVoiceSupportService]
/// in live mode (real on-device speech recognition + text-to-speech, no
/// vendor API key needed), [MockVoiceSupportService] in demo mode, so the
/// app stays fully explorable with no microphone.
class SupportVoicePage extends StatefulWidget {
  final VoiceSupportService? service;
  const SupportVoicePage({super.key, this.service});
  @override
  State<SupportVoicePage> createState() => _SupportVoicePageState();
}

class _SupportVoicePageState extends State<SupportVoicePage> {
  late final VoiceSupportService _service = widget.service ?? (SupabaseService.isConfigured ? DeviceVoiceSupportService() : MockVoiceSupportService());
  _VoiceState _state = _VoiceState.idle;
  String? _question;
  String? _answer;

  Future<void> _ask() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _state = _VoiceState.listening;
      _question = null;
      _answer = null;
    });
    try {
      final question = await _service.transcribe();
      if (!mounted) return;
      setState(() {
        _question = question;
        _state = _VoiceState.thinking;
      });
      final answer = await _service.answer(question);
      if (!mounted) return;
      setState(() {
        _answer = answer;
        _state = _VoiceState.answered;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _answer = l10n.supportVoiceError;
        _state = _VoiceState.answered;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (_state) {
      _VoiceState.idle => l10n.supportVoiceTapToAsk,
      _VoiceState.listening => l10n.supportVoiceListening,
      _VoiceState.thinking => l10n.supportVoiceThinking,
      _VoiceState.answered => l10n.supportVoiceTapToAskAgain,
    };
    return Scaffold(
      appBar: PageHeader(title: l10n.supportVoiceTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 32, 16, 24),
        children: [
          Center(
            child: Tooltip(
              message: label,
              child: InkWell(
                onTap: _state == _VoiceState.listening || _state == _VoiceState.thinking ? null : _ask,
                borderRadius: BorderRadius.circular(48),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: _state == _VoiceState.listening ? Accent.red50 : Brand.c50, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(Icons.mic_rounded, size: 40, color: _state == _VoiceState.listening ? Accent.red600 : Brand.c600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(label, style: AppTheme.sans(13, weight: FontWeight.w600, color: Neutral.c500))),
          if (_question != null) ...[
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.person_rounded, size: 14, color: Neutral.c400),
                    const SizedBox(width: 6),
                    Text(l10n.supportVoiceYouAsked, style: AppTheme.sans(11, weight: FontWeight.w700, color: Neutral.c500)),
                  ]),
                  const SizedBox(height: 6),
                  Text(_question!, style: AppTheme.sans(14, weight: FontWeight.w600)),
                ],
              ),
            ),
          ],
          if (_answer != null) ...[
            const SizedBox(height: 12),
            AppCard(
              color: Brand.c50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.volume_up_rounded, size: 14, color: Brand.c600),
                    const SizedBox(width: 6),
                    Text(l10n.supportVoiceAnswerLabel, style: AppTheme.sans(11, weight: FontWeight.w700, color: Brand.c700)),
                  ]),
                  const SizedBox(height: 6),
                  Text(_answer!, style: AppTheme.sans(14, color: Neutral.c700)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
