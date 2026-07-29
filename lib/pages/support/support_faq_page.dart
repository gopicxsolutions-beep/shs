import 'package:flutter/material.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';

class SupportFaqPage extends StatelessWidget {
  const SupportFaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Was `lib/data/support.dart`'s `mockFaqs` rendered verbatim in every
    // language — the only user-facing text on this whole page that never
    // went through `AppLocalizations`, unlike every other Support screen. A
    // Hindi/Telugu-only member switching languages still saw English FAQ
    // text she may not be able to read.
    final faqs = [
      (l10n.supportFaq1Question, l10n.supportFaq1Answer),
      (l10n.supportFaq2Question, l10n.supportFaq2Answer),
      (l10n.supportFaq3Question, l10n.supportFaq3Answer),
      (l10n.supportFaq4Question, l10n.supportFaq4Answer),
      (l10n.supportFaq5Question, l10n.supportFaq5Answer),
    ];
    return Scaffold(
      appBar: PageHeader(title: l10n.supportFaqTitle),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        itemBuilder: (context, i) {
          final (question, answer) = faqs[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padded: false,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(question, style: AppTheme.sans(13, weight: FontWeight.w700)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(answer, style: AppTheme.sans(13, color: Neutral.c600)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
