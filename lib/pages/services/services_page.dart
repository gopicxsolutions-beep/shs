import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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

  static const _shgManagement = <_Service>[
    _Service(Icons.groups_rounded, 'My SHG', TileTone.brand, Paths.shg),
    _Service(Icons.account_balance_wallet_rounded, 'Savings', TileTone.brand, Paths.savings),
    _Service(Icons.account_balance_rounded, 'Loans', TileTone.gold, Paths.loans),
    _Service(Icons.event_rounded, 'Meetings', TileTone.sky, Paths.meetings),
    _Service(Icons.receipt_long_rounded, 'Financial Records', TileTone.ink, Paths.financialCashbook),
    _Service(Icons.eco_rounded, 'Livelihoods', TileTone.brand, Paths.livelihood),
  ];

  static const _commerce = <_Service>[
    _Service(Icons.storefront_rounded, 'Marketplace', TileTone.gold, Paths.marketplace),
    _Service(Icons.qr_code_rounded, 'Digital Payments', TileTone.sky, Paths.payments),
  ];

  static const _learningSupport = <_Service>[
    _Service(Icons.description_rounded, 'Govt. Schemes', TileTone.violet, Paths.schemes),
    _Service(Icons.school_rounded, 'Training', TileTone.gold, Paths.training),
    _Service(Icons.support_agent_rounded, 'Support', TileTone.rose, Paths.support),
    _Service(Icons.smart_toy_rounded, 'AI Advisors', TileTone.sky, Paths.aiHub),
    // Soft hyphen (U+00AD) gives the 2-line label a sensible break point
    // instead of an arbitrary mid-word cut when this single long word
    // doesn't fit on one line at the grid's fixed tile width.
    _Service(Icons.campaign_rounded, 'Announce­ments', TileTone.brand, Paths.announcements),
  ];

  static const _insights = <_Service>[
    _Service(Icons.bar_chart_rounded, 'Reports', TileTone.violet, Paths.reports),
  ];

  static const _insightsStaff = <_Service>[
    _Service(Icons.show_chart_rounded, 'Analytics', TileTone.ink, Paths.analytics),
  ];

  static const _adminTools = <_Service>[
    _Service(Icons.people_rounded, 'Manage Users', TileTone.rose, Paths.adminUsers),
    _Service(Icons.settings_suggest_rounded, 'Manage Schemes', TileTone.gold, Paths.adminSchemes),
    _Service(Icons.dns_rounded, 'System Monitoring', TileTone.sky, Paths.adminMonitoring),
  ];

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AppState>().user.role;
    final isStaff = const {Role.crp, Role.clf, Role.admin}.contains(role);
    final isAdmin = role == Role.admin;

    return Scaffold(
      appBar: const PageHeader(title: 'Services'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _section(context, 'SHG Management', _shgManagement),
          _section(context, 'Commerce', _commerce),
          _section(context, 'Learning & Support', _learningSupport),
          _section(context, 'Insights', [..._insights, if (isStaff) ..._insightsStaff]),
          if (isAdmin) _section(context, 'Admin Tools', _adminTools),
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
