import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../models/types.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';

/// The very first screen a fresh install ever reaches — gated by the
/// router's redirect on `!appState.languageSelected` (see
/// `AppState.languageSelected`'s doc comment), so it only ever shows once
/// per device, before `SplashPage`/`LoginPage`/anything else in the auth
/// flow. A returning, already-signed-in account never sees this again even
/// if it predates this feature and happens to have never touched Settings
/// > Language, since the redirect only fires while `!appState.hasSession`.
///
/// No back button and no "skip" — every one of the three languages this
/// app supports is a complete, first-class UI (not a partial translation),
/// so there's no reasonable "continue without choosing" default to skip
/// to; picking one of the three *is* the minimal action this screen exists
/// for.
class LanguageSelectPage extends StatelessWidget {
  const LanguageSelectPage({super.key});

  Future<void> _select(BuildContext context, Language l) async {
    await context.read<AppState>().setLanguage(l);
    if (context.mounted) context.go(Paths.splash);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Neutral.c50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Brand.c600,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Brand.c600.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.translate_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              Text(l10n.languageSelectTitle, textAlign: TextAlign.center, style: AppTheme.display(22)),
              const SizedBox(height: 6),
              Text(l10n.languageSelectSubtitle, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
              const SizedBox(height: 28),
              AppCard(
                padded: false,
                child: Column(
                  children: Language.values.map((l) {
                    final (native, english) = languageDisplayNames[l]!;
                    final isLast = l == Language.values.last;
                    return Semantics(
                      button: true,
                      label: native == english ? native : '$native, $english',
                      child: ExcludeSemantics(
                        child: InkWell(
                          onTap: () => _select(context, l),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                            decoration: BoxDecoration(
                              border: isLast ? null : Border(bottom: BorderSide(color: Neutral.c100)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(native, style: AppTheme.sans(16, weight: FontWeight.w700)),
                                      if (native != english) Text(english, style: AppTheme.sans(12, color: Neutral.c500)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Neutral.c300),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
