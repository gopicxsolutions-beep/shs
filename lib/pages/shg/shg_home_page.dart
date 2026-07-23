import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/shg.dart';
import '../../models/types.dart';
import '../../repositories/shg_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';

class ShgHomePage extends StatelessWidget {
  const ShgHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLeaderOrStaff = appState.user.role != Role.member;
    final repo = ShgRepository();
    final shgId = appState.profile?.shgId;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.shgHomeTitle),
      body: AppAsyncBuilder<ShgProfile?>(
        future: () => repo.fetchShg(shgId),
        builder: (context, shg) {
          if (shg == null) {
            return AppEmptyState(icon: Icons.groups_rounded, message: l10n.shgHomeNotLinked);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                gradient: const LinearGradient(colors: [Brand.c700, Brand.c600]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text(shg.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
                      if (shg.grade != null) AppBadge(text: shg.grade!, tone: BadgeTone.neutral),
                    ]),
                    const SizedBox(height: 4),
                    Text('${shg.village ?? ''}, ${shg.district ?? ''}', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                    if (shg.regNumber != null) ...[
                      const SizedBox(height: 8),
                      Text(l10n.shgHomeRegNumberLabel(shg.regNumber!), style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconTile(onTap: () => context.go(Paths.shgMembers), icon: Icons.groups_rounded, label: l10n.shgHomeMembersTile, tone: TileTone.brand),
                  IconTile(onTap: () => context.go(Paths.shgDocuments), icon: Icons.folder_rounded, label: l10n.shgHomeDocumentsTile, tone: TileTone.gold),
                ],
              ),
              const SizedBox(height: 24),
              SectionHeader(title: l10n.shgHomeFederationSection),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Soft hyphen (baked into the localized string itself)
                    // gives the narrow label column a sensible break point
                    // instead of an arbitrary mid-word cut.
                    _row(l10n.shgHomeVillageOrgLabel, shg.vo ?? '—'),
                    const SizedBox(height: 8),
                    _row(l10n.shgHomeClfLabel, shg.clf ?? '—'),
                    const SizedBox(height: 8),
                    _row(l10n.shgHomeMandalLabel, shg.mandal ?? '—'),
                    const SizedBox(height: 8),
                    // `ShgProfile.formationDate` (`shgs.formation_date`) was
                    // parsed by `ShgRepository.fetchShg()` but never
                    // displayed anywhere — a real, populated field with no
                    // UI to show it, the same "data with no way to see it"
                    // shape as round 65's orphaned routes.
                    _row(l10n.shgHomeFormedLabel, shg.formationDate != null ? DateFormat('dd MMM yyyy').format(shg.formationDate!) : '—'),
                  ],
                ),
              ),
              if (isLeaderOrStaff) ...[
                const SizedBox(height: 20),
                SectionHeader(title: l10n.shgHomeBankDetailsSection),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(l10n.shgHomeBankLabel, shg.bankName ?? '—'),
                      const SizedBox(height: 8),
                      _row(l10n.shgHomeAccountLabel, shg.bankAccount ?? '—'),
                      const SizedBox(height: 8),
                      _row(l10n.shgHomeIfscLabel, shg.ifsc ?? '—'),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // `label` is a short fixed caption ("Bank", "IFSC", ...) so it keeps its
  // natural width; `value` is real SHG/bank data of unbounded length (a
  // long bank branch name, a full account number, ...) and previously had
  // no flex at all, so it overflowed the row instead of wrapping.
  //
  // "short" only held at 1.0x text scale, though — "Village Organisation"
  // is long enough that at 1.5-2x scaled text (a real accessibility
  // setting, not just a hypothetically long label) it alone overflows the
  // row before `value` even gets a say. `Flexible`+ellipsis on the label
  // too keeps both sides visible instead of throwing.
  Widget _row(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.sans(12, color: Neutral.c500))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: AppTheme.sans(12, weight: FontWeight.w700), textAlign: TextAlign.right)),
        ],
      );
}
