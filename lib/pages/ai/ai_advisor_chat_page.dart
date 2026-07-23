import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/ai_advisor.dart';
import '../../repositories/ai_advisor_repository.dart';
import '../../services/ai_advisor_service.dart' show AiAdvisorRequestException;
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
  // Production call sites never pass this — it exists so tests can inject a
  // repository backed by a fake AiAdvisorService that throws a specific
  // error shape, to verify each distinguishable failure renders its own
  // message (see test/pages/ai_advisor_chat_error_messages_test.dart).
  final AiAdvisorRepository? repository;
  const AiAdvisorChatPage({
    super.key,
    required this.advisorType,
    required this.title,
    required this.hint,
    this.repository,
  });

  @override
  State<AiAdvisorChatPage> createState() => _AiAdvisorChatPageState();
}

class _AiAdvisorChatPageState extends State<AiAdvisorChatPage> {
  late final AiAdvisorRepository _repo;
  final _query = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatEntry> _entries = [];
  bool _loaded = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? AiAdvisorRepository();
  }

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
      final l10n = AppLocalizations.of(context);
      final message = _errorMessageFor(e, l10n);
      setState(() {
        _entries.add(_ChatEntry(mine: false, text: message));
        _asking = false;
      });
      _scrollToEnd();
    }
  }

  // Threads the ai-advisor-proxy Edge Function's actual, distinguishable
  // failure reason through to the member instead of flattening every
  // rejection into one of two generic messages (docs/AI_MODULES.md §2.2 /
  // §6's previously-disclosed gap). The function already crafts a specific,
  // member-safe message per case (see AiAdvisorRequestException's doc
  // comment and supabase/functions/ai-advisor-proxy/index.ts +
  // moderation.ts) — most importantly the content-moderation pre-filter's
  // supportive, safety-oriented self-harm rejection text, which must reach
  // the member verbatim rather than as "something went wrong".
  String _errorMessageFor(Object error, AppLocalizations? l10n) {
    if (error is AiAdvisorRequestException) {
      // 400 (validation/moderation pre-filter) and 429 (rate limit): the
      // server's own `reason` is already written to be shown to the member
      // as-is — show it verbatim.
      if (error.statusCode == 400 || error.statusCode == 429) {
        return error.reason;
      }
      // 401/500/502: an upstream/auth/provider failure that's the
      // service's fault, not the member's. Some of those raw reasons (e.g.
      // "Internal error") aren't written for end users, so this bucket
      // gets one shared, honest message instead of the raw reason.
      return l10n?.aiAdvisorUpstreamUnavailable ?? 'The advisor service is temporarily unavailable right now. Please try again in a moment.';
    }
    // Same isNetworkError-branched, localized message the rest of the app
    // uses (AppAsyncBuilder, otp_page.dart) instead of one hardcoded
    // English string regardless of cause — a dropped connection and a
    // genuinely unclassifiable failure are different problems and
    // shouldn't look identical to the member.
    return isNetworkError(error)
        ? (l10n?.asyncErrorNetwork ??
              'Check your internet connection and try again.')
        : (l10n?.asyncErrorGeneric ??
              'Something went wrong. Please try again.');
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
