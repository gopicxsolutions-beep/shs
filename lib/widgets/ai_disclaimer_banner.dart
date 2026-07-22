import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// Shown on every AI-advisor-branded screen (the 3 chat advisors, their hub,
/// and the Voice Assistant) — a lightweight, unmissable reminder that
/// answers are AI-generated and not a substitute for professional or human
/// judgement. Deliberately present on every one of those screens rather than
/// a one-time dismissible notice, since a member can open any of them
/// independently without passing through the others first.
class AiDisclaimerBanner extends StatelessWidget {
  const AiDisclaimerBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: l10n?.aiDisclaimer ?? _fallback,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: Accent.amber50,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Accent.amber800,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n?.aiDisclaimer ?? _fallback,
                  style: AppTheme.sans(11, color: Accent.amber800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _fallback =
    'AI-generated guidance — may be inaccurate. Not professional financial, legal, or medical advice; confirm important decisions with your SHG leader or a qualified advisor.';
