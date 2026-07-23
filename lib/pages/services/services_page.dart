import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../layout/page_header.dart';
import '../../models/types.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../widgets/icon_tile.dart';
import '../../widgets/section_header.dart';

class _Service {
  final IconData icon;
  final String label;
  final TileTone tone;
  final String path;
  const _Service(this.icon, this.label, this.tone, this.path);
}

/// A full directory of every module reachable by the current role — the
/// "Services" tab, distinct from each dashboard's curated shortcuts.
/// Reached from the center bottom-nav button on every role.
class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  static List<_Service> _shgManagement(AppLocalizations l10n) => [
        _Service(Icons.groups_rounded, l10n.navMySHG, TileTone.brand, Paths.shg),
        _Service(Icons.account_balance_wallet_rounded, l10n.servicesSavingsLabel, TileTone.brand, Paths.savings),
        _Service(Icons.account_balance_rounded, l10n.servicesLoansLabel, TileTone.gold, Paths.loans),
        _Service(Icons.event_rounded, l10n.servicesMeetingsLabel, TileTone.sky, Paths.meetings),
        _Service(Icons.receipt_long_rounded, l10n.servicesFinancialRecordsLabel, TileTone.ink, Paths.financialCashbook),
        _Service(Icons.eco_rounded, l10n.servicesLivelihoodsLabel, TileTone.brand, Paths.livelihood),
      ];

  static List<_Service> _commerce(AppLocalizations l10n) => [
        _Service(Icons.storefront_rounded, l10n.servicesMarketplaceLabel, TileTone.gold, Paths.marketplace),
        _Service(Icons.qr_code_rounded, l10n.servicesDigitalPaymentsLabel, TileTone.sky, Paths.payments),
      ];

  static List<_Service> _learningSupport(AppLocalizations l10n) => [
        _Service(Icons.description_rounded, l10n.servicesGovtSchemesLabel, TileTone.violet, Paths.schemes),
        _Service(Icons.school_rounded, l10n.servicesTrainingLabel, TileTone.gold, Paths.training),
        _Service(Icons.support_agent_rounded, l10n.servicesSupportLabel, TileTone.rose, Paths.support),
        _Service(Icons.smart_toy_rounded, l10n.servicesAiAdvisorsLabel, TileTone.sky, Paths.aiHub),
        // Soft hyphen (U+00AD) gives the 2-line label a sensible break point
        // instead of an arbitrary mid-word cut when this single long word
        // doesn't fit on one line at the grid's fixed tile width.
        _Service(Icons.campaign_rounded, l10n.servicesAnnouncementsLabel, TileTone.brand, Paths.announcements),
      ];

  static List<_Service> _insights(AppLocalizations l10n) => [
        _Service(Icons.bar_chart_rounded, l10n.servicesReportsLabel, TileTone.violet, Paths.reports),
      ];

  static List<_Service> _insightsStaff(AppLocalizations l10n) => [
        _Service(Icons.show_chart_rounded, l10n.servicesAnalyticsLabel, TileTone.ink, Paths.analytics),
      ];

  static List<_Service> _adminTools(AppLocalizations l10n) => [
        _Service(Icons.people_rounded, l10n.servicesManageUsersLabel, TileTone.rose, Paths.adminUsers),
        _Service(Icons.settings_suggest_rounded, l10n.servicesManageSchemesLabel, TileTone.gold, Paths.adminSchemes),
        _Service(Icons.dns_rounded, l10n.servicesSystemMonitoringLabel, TileTone.sky, Paths.adminMonitoring),
      ];

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AppState>().user.role;
    final isStaff = const {Role.crp, Role.clf, Role.admin}.contains(role);
    final isAdmin = role == Role.admin;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: PageHeader(title: l10n.servicesTitle),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _section(context, l10n.servicesShgManagementSection, _shgManagement(l10n)),
          _section(context, l10n.servicesCommerceSection, _commerce(l10n)),
          _section(context, l10n.servicesLearningSupportSection, _learningSupport(l10n)),
          _section(context, l10n.servicesInsightsSection, [..._insights(l10n), if (isStaff) ..._insightsStaff(l10n)]),
          if (isAdmin) _section(context, l10n.servicesAdminToolsSection, _adminTools(l10n)),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<_Service> services) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          Wrap(
            spacing: 12,
            runSpacing: 16,
            children: services.map((s) => IconTile(onTap: () => context.go(s.path), icon: s.icon, label: s.label, tone: s.tone)).toList(),
          ),
        ],
      ),
    );
  }
}
