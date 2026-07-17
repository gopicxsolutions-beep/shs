import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/shg.dart';
import '../../routes/paths.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});
  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _name = TextEditingController();
  bool _shgSelected = false;

  Widget _field(String label, {String? placeholder, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
        const SizedBox(height: 6),
        Container(
          height: 44,
          decoration: BoxDecoration(border: Border.all(color: Neutral.c200), borderRadius: BorderRadius.circular(12), color: Colors.white),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: controller != null
              ? TextField(
                  controller: controller,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(border: InputBorder.none, hintText: placeholder),
                  style: AppTheme.sans(14),
                )
              : Text(placeholder ?? '', style: AppTheme.sans(14)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final valid = _name.text.isNotEmpty && _shgSelected;
    return Scaffold(
      backgroundColor: Neutral.c50,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 64, height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 100),
                decoration: BoxDecoration(
                  color: Brand.c600, borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Brand.c600.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.account_circle_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 20),
              Text('Create your profile', textAlign: TextAlign.center, style: AppTheme.display(22)),
              const SizedBox(height: 6),
              Text('Tell us a bit about yourself to get started', textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
              const SizedBox(height: 28),
              _field('Full name', placeholder: 'e.g. Lakshmi Devi', controller: _name),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _field('Village', placeholder: 'Kondapur')),
                const SizedBox(width: 12),
                Expanded(child: _field('Mandal', placeholder: 'Hanamkonda')),
              ]),
              const SizedBox(height: 14),
              _field('District', placeholder: 'Warangal'),
              const SizedBox(height: 14),
              Text('Your SHG', style: AppTheme.sans(12, weight: FontWeight.w700, color: Neutral.c600)),
              const SizedBox(height: 6),
              AppCard(
                onTap: () => setState(() => _shgSelected = true),
                borderColor: _shgSelected ? Brand.c500 : null,
                child: _shgSelected
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ShgInfo.name, style: AppTheme.sans(14, weight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('${ShgInfo.village}, ${ShgInfo.district}', style: AppTheme.sans(12, color: Neutral.c500)),
                            ],
                          ),
                          Text('Selected', style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600)),
                        ],
                      )
                    : Row(children: [
                        Icon(Icons.search, size: 16, color: Neutral.c500),
                        const SizedBox(width: 8),
                        Text('Search & select your SHG', style: AppTheme.sans(14, color: Neutral.c500)),
                      ]),
              ),
              const SizedBox(height: 24),
              AppButton(label: 'Continue', fullWidth: true, size: ButtonSize.lg, onPressed: valid ? () => context.go(Paths.roleSelect) : null),
            ],
          ),
        ),
      ),
    );
  }
}
