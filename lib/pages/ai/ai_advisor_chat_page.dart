import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/ai_advisor.dart';
import '../../repositories/ai_advisor_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/ai_disclaimer_banner.dart';
import '../../widgets/async_state.dart';

class _ChatEntry {
  final bool mine;
  final String text;
  const _ChatEntry({required this.mine, required this.text});
}

/// One shared screen reused across the Financial Advisor, Scheme
/// Recommender, and Market Advisor routes — they're identical shape, just
/// scoped by `advisorType`.
class AiAdvisorChatPage extends StatefulWidget {
  final String advisorType;
  final String title;
  final String hint;
  const AiAdvisorChatPage({
    super.key,
    required this.advisorType,
    required this.title,
    required this.hint,
  });

  @override
  State<AiAdvisorChatPage> createState() => _AiAdvisorChatPageState();
}

class _AiAdvisorChatPageState extends State<AiAdvisorChatPage> {
  final _repo = AiAdvisorRepository();
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatEntry> _entries = [];
  bool _loaded = false;
  bool _asking = false;

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // The list has no fixed item extent (message bubbles wrap to content), so
  // the true bottom isn't knowable until the frame this new entry appears in
  // has actually laid out — jumping inside setState would still see the
  // pre-append maxScrollExtent. Scheduling for the end of that frame is what
  // makes this reliable instead of landing one message short.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<List<AiAdvisorLog>> _loadHistory(String? memberId) async {
    final history = await _repo.fetchHistory(
      memberId: memberId,
      advisorType: widget.advisorType,
    );
    if (!_loaded) {
      for (final log in history) {
        _entries.add(_ChatEntry(mine: true, text: log.query));
        if (log.response != null) {
          _entries.add(_ChatEntry(mine: false, text: log.response!));
        }
      }
      _loaded = true;
      if (_entries.isNotEmpty) _scrollToEnd();
    }
    return history;
  }

  Future<void> _ask(String? memberId) async {
    final text = _query.text.trim();
    if (text.isEmpty || _asking) return;
    setState(() {
      _entries.add(_ChatEntry(mine: true, text: text));
      _asking = true;
    });
    _query.clear();
    _scrollToEnd();
    try {
      final response = await _repo.ask(
        memberId: memberId,
        advisorType: widget.advisorType,
        query: text,
      );
      if (!mounted) return;
      setState(() {
        _entries.add(_ChatEntry(mine: false, text: response));
        _asking = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      // Same isNetworkError-branched, localized message the rest of the app
      // uses (AppAsyncBuilder, otp_page.dart) instead of one hardcoded
      // English string regardless of cause — a dropped connection and a
      // genuine advisor-service failure (rate limit, malformed response)
      // are different problems and shouldn't look identical to the member.
      final l10n = AppLocalizations.of(context);
      final message = isNetworkError(e)
          ? (l10n?.asyncErrorNetwork ??
                'Check your internet connection and try again.')
          : (l10n?.asyncErrorGeneric ??
                'Something went wrong. Please try again.');
      setState(() {
        _entries.add(_ChatEntry(mine: false, text: message));
        _asking = false;
      });
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: PageHeader(title: widget.title),
      body: Column(
        children: [
          const AiDisclaimerBanner(),
          Expanded(
            child: AppAsyncBuilder<List<AiAdvisorLog>>(
              future: () => _loadHistory(memberId),
              builder: (context, _) {
                if (_entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        widget.hint,
                        textAlign: TextAlign.center,
                        style: AppTheme.sans(13, color: Neutral.c500),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    return Semantics(
                      label: '${e.mine ? 'You' : 'Advisor'}: ${e.text}',
                      child: ExcludeSemantics(
                        child: Align(
                          alignment: e.mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            constraints: const BoxConstraints(maxWidth: 280),
                            decoration: BoxDecoration(
                              color: e.mine ? Brand.c500 : Neutral.c100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              e.text,
                              style: AppTheme.sans(
                                13,
                                color: e.mine ? Colors.white : Neutral.c700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _query,
                    maxLength: 500,
                    textInputAction: TextInputAction.send,
                    style: AppTheme.sans(13),
                    decoration: InputDecoration(
                      hintText: 'Ask a question…',
                      filled: true,
                      fillColor: Neutral.c50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      counterText: '',
                    ),
                    onSubmitted: (_) => _ask(memberId),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _asking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send_rounded, color: Brand.c600),
                  onPressed: _asking ? null : () => _ask(memberId),
                  tooltip: 'Send',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
