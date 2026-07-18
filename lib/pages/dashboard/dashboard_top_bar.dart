import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/types.dart';
import '../../repositories/announcement_repository.dart';
import '../../routes/paths.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/avatar.dart';

class DashboardTopBar extends StatefulWidget {
  const DashboardTopBar({super.key});

  @override
  State<DashboardTopBar> createState() => _DashboardTopBarState();
}

class _DashboardTopBarState extends State<DashboardTopBar> {
  final _repo = AnnouncementRepository();
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    _repo.fetchForShg(appState.profile?.shgId, appState.profile?.id).then((list) {
      if (mounted) setState(() => _unread = list.where((a) => !a.read).length);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().user;
    final roleInfo = roleInfoFor(user.role);
    final unread = _unread;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 64),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Brand.c700, Brand.c600, Brand.c500]),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => context.go(Paths.profileSettings),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(roleInfo.label, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                        const SizedBox(width: 4),
                        Icon(Icons.unfold_more, size: 12, color: Colors.white.withValues(alpha: 0.6)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Namaste, ${user.name.split(' ').first} 🙏', style: AppTheme.display(18, color: Colors.white)),
                const SizedBox(height: 2),
                Text(user.shgName, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
              ],
            ),
          ),
          Row(
            children: [
              Tooltip(
                message: unread > 0 ? '$unread unread announcements' : 'Announcements',
                child: InkWell(
                  onTap: () => context.go(Paths.announcements),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Stack(children: [
                      const Center(child: Icon(Icons.notifications_rounded, color: Colors.white, size: 18)),
                      if (unread > 0)
                        Positioned(
                          right: 8, top: 8,
                          child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Gold.c400, shape: BoxShape.circle, border: Border.all(color: Brand.c600, width: 2))),
                        ),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Profile',
                child: InkWell(
                  onTap: () => context.go(Paths.profile),
                  child: AppAvatar(name: user.name, size: 40, ringColor: Colors.white.withValues(alpha: 0.4)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
