import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  static List<(IconData, String)> _features(AppLocalizations l10n) => [
        (Icons.trending_up_rounded, l10n.splashFeatureSavingsLoans),
        (Icons.groups_2_rounded, l10n.splashFeatureGroupManagement),
        (Icons.shield_rounded, l10n.splashFeatureGovtSchemes),
        (Icons.eco_rounded, l10n.splashFeatureLivelihoods),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -1.2), radius: 1.6, colors: [Brand.c500, Brand.c700, Brand.c950], stops: [0, 0.45, 1]),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.eco_rounded, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                l10n.splashBrandName,
                                style: AppTheme.sans(13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(l10n.splashHeadline, style: AppTheme.display(30, color: Colors.white, weight: FontWeight.w700), textAlign: TextAlign.left),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Text(
                              l10n.splashSubtitle,
                              style: AppTheme.sans(13, color: Colors.white.withValues(alpha: 0.75)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.6,
                          children: _features(l10n)
                              .map((f) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        Icon(f.$1, size: 16, color: Gold.c300),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(f.$2, style: AppTheme.sans(12, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)), overflow: TextOverflow.ellipsis)),
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => context.go(Paths.login),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Brand.c700,
                      elevation: 8,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(l10n.splashGetStarted, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(l10n.splashAvailableLanguages, style: AppTheme.sans(11, color: Colors.white.withValues(alpha: 0.6))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
