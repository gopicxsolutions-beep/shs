import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../models/profile.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'app_card.dart';

/// Opens the shared SHG search/pick bottom sheet, resolving to the chosen
/// [ShgSearchResult] or `null` if dismissed without a selection. [search] is
/// the caller's `searchShgs(query)` — different callers (onboarding's
/// `ProfileRepository`, admin's `AdminRepository`) hit the same
/// `shg_directory` view but shouldn't have to share a repository type.
Future<ShgSearchResult?> showShgSearchSheet(BuildContext context, {required Future<List<ShgSearchResult>> Function(String query) search}) {
  return showModalBottomSheet<ShgSearchResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ShgSearchSheet(search: search),
  );
}

class _ShgSearchSheet extends StatefulWidget {
  final Future<List<ShgSearchResult>> Function(String query) search;
  const _ShgSearchSheet({required this.search});
  @override
  State<_ShgSearchSheet> createState() => _ShgSearchSheetState();
}

class _ShgSearchSheetState extends State<_ShgSearchSheet> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<ShgSearchResult> _results = [];
  bool _loading = false;
  String? _error;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String value) async {
    // A later keystroke can start a second search before an earlier one's
    // response arrives; only the most recent request may write its results,
    // so a slow stale response can't clobber what the user is now seeing.
    final generation = ++_searchGeneration;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.search(value);
      if (mounted && generation == _searchGeneration) setState(() => _results = results);
    } catch (_) {
      if (mounted && generation == _searchGeneration) setState(() => _error = 'Could not load SHGs. Please try again.');
    } finally {
      if (mounted && generation == _searchGeneration) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: 480,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.findYourShg, style: AppTheme.display(16)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Neutral.c200), borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(children: [
                  Icon(Icons.search, size: 16, color: Neutral.c400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _query,
                      onChanged: _onChanged,
                      decoration: InputDecoration(border: InputBorder.none, hintText: l10n.searchShgHint),
                      style: AppTheme.sans(14),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              if (_error != null) Text(_error!, style: AppTheme.sans(12, color: Accent.red600)),
              Expanded(
                child: _loading
                    ? Center(child: Semantics(label: l10n.commonLoading, liveRegion: true, child: const CircularProgressIndicator()))
                    : _results.isEmpty
                        ? Center(child: Text(l10n.noShgsFound, style: AppTheme.sans(13, color: Neutral.c400)))
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final shg = _results[i];
                              return AppCard(
                                onTap: () => Navigator.of(context).pop(shg),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(shg.name, style: AppTheme.sans(14, weight: FontWeight.w700)),
                                    const SizedBox(height: 2),
                                    Text('${shg.village}, ${shg.district}', style: AppTheme.sans(12, color: Neutral.c500)),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
