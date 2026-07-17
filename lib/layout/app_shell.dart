import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/types.dart';
import '../routes/paths.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';

class AppShell extends StatelessWidget {
  final Widget child;
  final String location;
  const AppShell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(bottom: false, child: child),
      bottomNavigationBar: _BottomNav(location: location),
    );
  }
}

class _NavItem {
  final String to;
  final String label;
  final IconData icon;
  final bool center;
  const _NavItem(this.to, this.label, this.icon, {this.center = false});
}

class _BottomNav extends StatelessWidget {
  final String location;
  const _BottomNav({required this.location});

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AppState>().user.role;
    final isOversight = role == Role.crp || role == Role.clf || role == Role.admin;
    final items = <_NavItem>[
      const _NavItem(Paths.dashboard, 'Home', Icons.home_rounded),
      _NavItem(Paths.shg, isOversight ? 'SHGs' : 'My SHG', isOversight ? Icons.apartment_rounded : Icons.groups_rounded),
      const _NavItem(Paths.services, 'Services', Icons.grid_view_rounded, center: true),
      const _NavItem(Paths.marketplace, 'Market', Icons.storefront_rounded),
      const _NavItem(Paths.profile, 'Profile', Icons.person_rounded),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.97), border: Border(top: BorderSide(color: Neutral.c100)), boxShadow: navShadow),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: items.map((item) {
              final active = location == item.to || (item.to != Paths.dashboard && location.startsWith(item.to));
              return Expanded(
                child: InkWell(
                  onTap: () => GoRouter.of(context).go(item.to),
                  child: item.center
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -14),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: active ? Brand.c700 : Brand.c600,
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Brand.c600.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 6))],
                                ),
                                child: Icon(item.icon, color: Colors.white, size: 24),
                              ),
                            ),
                            Transform.translate(
                              offset: const Offset(0, -10),
                              child: Text(item.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? Brand.c600 : Neutral.c500)),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item.icon, size: 22, color: active ? Brand.c600 : Neutral.c400),
                            const SizedBox(height: 2),
                            Text(item.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: active ? Brand.c600 : Neutral.c400)),
                          ],
                        ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
