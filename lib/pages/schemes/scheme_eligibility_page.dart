import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../layout/page_header.dart';
import '../../models/scheme.dart';
import '../../repositories/scheme_repository.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';

/// A simple client-side heuristic: matches the user's yes/no answers against
/// keywords in each scheme's eligibility text. This is NOT a real government
/// eligibility engine (that would need an external rules API) — it's a
/// placeholder that gives a useful first estimate, per the "build the
/// architecture now, wire a real API later" requirement.
class SchemeEligibilityPage extends StatefulWidget {
  const SchemeEligibilityPage({super.key});
  @override
  State<SchemeEligibilityPage> createState() => _SchemeEligibilityPageState();
}

class _SchemeEligibilityPageState extends State<SchemeEligibilityPage> {
  final _repo = SchemeRepository();
  final Map<String, bool> _answers = {
    'SHG registered 6+ months': true,
    'BPL / rural household': true,
    'Age 18 or above': true,
    'No prior subsidy availed for this scheme': true,
  };

  static const _keywordsByQuestion = {
    'SHG registered 6+ months': ['6+ months', '6 month'],
    'BPL / rural household': ['bpl', 'rural'],
    'Age 18 or above': ['age 18'],
    'No prior subsidy availed for this scheme': ['no prior'],
  };

  bool _isLikelyEligible(Scheme scheme) {
    if (scheme.eligibility.isEmpty) return true;
    for (final criterion in scheme.eligibility) {
      final lower = criterion.toLowerCase();
      for (final entry in _keywordsByQuestion.entries) {
        final matchesKeyword = _keywordsByQuestion[entry.key]!.any((k) => lower.contains(k));
        if (matchesKeyword && _answers[entry.key] == false) return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageHeader(title: 'Eligibility Checker'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Answer a few questions to see which schemes you may qualify for.', style: AppTheme.sans(12, color: Neutral.c500)),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              children: _answers.keys.map((q) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(q, style: AppTheme.sans(13, weight: FontWeight.w600)),
                    value: _answers[q]!,
                    activeThumbColor: Brand.c600,
                    onChanged: (v) => setState(() => _answers[q] = v),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 24),
          Text('Likely Eligible', style: AppTheme.display(15)),
          const SizedBox(height: 12),
          AppAsyncBuilder<List<Scheme>>(
            future: _repo.fetchSchemes,
            builder: (context, schemes) {
              final eligible = schemes.where(_isLikelyEligible).toList();
              if (eligible.isEmpty) {
                return const AppEmptyState(icon: Icons.info_outline_rounded, message: 'No schemes match your current answers');
              }
              return Column(
                children: eligible.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        onTap: () => context.go(Paths.schemeDetail(s.id)),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.name, style: AppTheme.sans(13, weight: FontWeight.w700)),
                                Text(s.benefit ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(11, color: Neutral.c500)),
                              ],
                            ),
                          ),
                          const AppBadge(text: 'Likely eligible', tone: BadgeTone.success),
                        ]),
                      ),
                    )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
