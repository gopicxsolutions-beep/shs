import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../layout/page_header.dart';
import '../../models/ai_advisor.dart';
import '../../repositories/ai_advisor_repository.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
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
  const AiAdvisorChatPage({super.key, required this.advisorType, required this.title, required this.hint});

  @override
  State<AiAdvisorChatPage> createState() => _AiAdvisorChatPageState();
}

class _AiAdvisorChatPageState extends State<AiAdvisorChatPage> {
  final _repo = AiAdvisorRepository();
  final _query = TextEditingController();
  final List<_ChatEntry> _entries = [];
  bool _loaded = false;
  bool _asking = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<List<AiAdvisorLog>> _loadHistory(String? memberId) async {
    final history = await _repo.fetchHistory(memberId: memberId, advisorType: widget.advisorType);
    if (!_loaded) {
      for (final log in history) {
        _entries.add(_ChatEntry(mine: true, text: log.query));
        if (log.response != null) _entries.add(_ChatEntry(mine: false, text: log.response!));
      }
      _loaded = true;
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
    final response = await _repo.ask(memberId: memberId, advisorType: widget.advisorType, query: text);
    if (!mounted) return;
    setState(() {
      _entries.add(_ChatEntry(mine: false, text: response));
      _asking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final memberId = appState.profile?.id;

    return Scaffold(
      appBar: PageHeader(title: widget.title),
      body: Column(
        children: [
          Expanded(
            child: AppAsyncBuilder<List<AiAdvisorLog>>(
              future: () => _loadHistory(memberId),
              builder: (context, _) {
                if (_entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(widget.hint, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, i) {
                    final e = _entries[i];
                    return Align(
                      alignment: e.mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 280),
                        decoration: BoxDecoration(color: e.mine ? Brand.c500 : Neutral.c100, borderRadius: BorderRadius.circular(14)),
                        child: Text(e.text, style: AppTheme.sans(13, color: e.mine ? Colors.white : Neutral.c700)),
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
                    style: AppTheme.sans(13),
                    decoration: InputDecoration(
                      hintText: 'Ask a question…',
                      filled: true,
                      fillColor: Neutral.c50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _ask(memberId),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _asking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.send_rounded, color: Brand.c600),
                  onPressed: _asking ? null : () => _ask(memberId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
