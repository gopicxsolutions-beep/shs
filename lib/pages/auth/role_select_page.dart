import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/types.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_card.dart';

class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

  static const _icons = <Role, IconData>{
    Role.member: Icons.groups_rounded,
    Role.leader: Icons.workspace_premium_rounded,
    Role.crp: Icons.radar_rounded,
    Role.clf: Icons.apartment_rounded,
    Role.admin: Icons.shield_rounded,
  };

  static const _tones = <Role, (Color, Color)>{
    Role.member: (Brand.c50, Brand.c600),
    Role.leader: (Gold.c50, Gold.c600),
    Role.crp: (Accent.sky50, Accent.sky600),
    Role.clf: (Accent.violet100, Accent.violet600),
    Role.admin: (Accent.rose50, Accent.rose600),
  };

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    return Scaffold(
      backgroundColor: Neutral.c50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            children: [
              Text('Continue as', textAlign: TextAlign.center, style: AppTheme.display(22)),
              const SizedBox(height: 6),
              Text('Choose your role in the SHG ecosystem to see a tailored experience', textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
              const SizedBox(height: 28),
              ...roles.map((r) {
                final (bg, fg) = _tones[r.id]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    onTap: () async {
                      await appState.setRole(r.id);
                      await appState.setAuthenticated(true);
                      if (context.mounted) context.go(Paths.dashboard);
                    },
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                          child: Icon(_icons[r.id], color: fg, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.label, style: AppTheme.sans(14, weight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(r.description, style: AppTheme.sans(12, color: Neutral.c500)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: Neutral.c300, size: 18),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
