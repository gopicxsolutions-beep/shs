import 'package:flutter/material.dart';
import '../../layout/page_header.dart';
import '../../services/voice_support_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';

enum _VoiceState { idle, listening, thinking, answered }

/// Voice support powered by [VoiceSupportService] — currently
/// [MockVoiceSupportService], since no real STT/TTS provider is wired yet.
/// The record → transcribe → answer → play flow is fully real; only the
/// speech recognition and synthesis itself are simulated. See
/// docs/DEVELOPMENT_PROGRESS.md's "External API abstraction plan".
class SupportVoicePage extends StatefulWidget {
  final VoiceSupportService? service;
  const SupportVoicePage({super.key, this.service});
  @override
  State<SupportVoicePage> createState() => _SupportVoicePageState();
}

class _SupportVoicePageState extends State<SupportVoicePage> {
  late final VoiceSupportService _service = widget.service ?? MockVoiceSupportService();
  _VoiceState _state = _VoiceState.idle;
  String? _question;
  String? _answer;

  Future<void> _ask() async {
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
        _answer = 'Sorry, something went wrong. Please try again.';
        _state = _VoiceState.answered;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (_state) {
      _VoiceState.idle => 'Tap to ask a question',
      _VoiceState.listening => 'Listening…',
      _VoiceState.thinking => 'Finding an answer…',
      _VoiceState.answered => 'Tap to ask again',
    };
    return Scaffold(
      appBar: const PageHeader(title: 'Voice Support'),
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
                    Text('You asked', style: AppTheme.sans(11, weight: FontWeight.w700, color: Neutral.c500)),
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
                    Text('Answer', style: AppTheme.sans(11, weight: FontWeight.w700, color: Brand.c700)),
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
