import 'package:flutter/material.dart';
import '../../data/support.dart' as mock;
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
    return Scaffold(
      appBar: PageHeader(title: l10n.supportFaqTitle),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: mock.mockFaqs.length,
        itemBuilder: (context, i) {
          final faq = mock.mockFaqs[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padded: false,
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(faq.question, style: AppTheme.sans(13, weight: FontWeight.w700)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(faq.answer, style: AppTheme.sans(13, color: Neutral.c600)),
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
