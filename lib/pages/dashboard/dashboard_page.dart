import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/types.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import 'admin_dashboard.dart';
import 'clf_dashboard.dart';
import 'crp_dashboard.dart';
import 'dashboard_top_bar.dart';
import 'leader_dashboard.dart';
import 'member_dashboard.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AppState>().user.role;
    return Container(
      color: Neutral.c50,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const DashboardTopBar(),
            switch (role) {
              Role.member => const MemberDashboard(),
              Role.leader => const LeaderDashboard(),
              Role.crp => const CRPDashboard(),
              Role.clf => const CLFDashboard(),
              Role.admin => const AdminDashboard(),
            },
          ],
        ),
      ),
    );
  }
}
