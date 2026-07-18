import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../routes/paths.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/input_formatters.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _controller = TextEditingController();
  final _authService = AuthService();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = '+91${_controller.text}';
    if (!SupabaseService.isConfigured) {
      context.go(Paths.otp, extra: phone);
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _authService.sendOtp(phone);
      if (mounted) context.go(Paths.otp, extra: phone);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send OTP. Please check the number and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _controller.text.length >= 10;
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Neutral.c50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: Brand.c600, borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Brand.c600.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              Text(l10n.loginTitle, style: AppTheme.display(22)),
              const SizedBox(height: 6),
              Text(l10n.loginSubtitle, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
              const SizedBox(height: 28),
              Container(
                decoration: BoxDecoration(border: Border.all(color: Neutral.c200), borderRadius: BorderRadius.circular(12), color: Colors.white),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Text('+91', style: AppTheme.sans(14, weight: FontWeight.w600, color: Neutral.c500)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        inputFormatters: wholeNumberInputFormatters,
                        maxLength: 10,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) {
                          if (_controller.text.length >= 10 && !_sending) _submit();
                        },
                        decoration: const InputDecoration(border: InputBorder.none, counterText: '', hintText: '98765 43210'),
                        style: AppTheme.sans(14),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: Text(_error!, style: AppTheme.sans(11, color: Accent.red600))),
              ],
              const SizedBox(height: 16),
              AppButton(
                label: _sending ? l10n.loginSending : l10n.loginSendOtp,
                fullWidth: true,
                size: ButtonSize.lg,
                onPressed: valid && !_sending ? _submit : null,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Brand.c50, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_rounded, size: 16, color: Brand.c600),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Your data is protected under DAY-NRLM guidelines. We never share your Aadhaar details.', style: AppTheme.sans(11, color: Brand.c700))),
                  ],
                ),
              ),
              const Spacer(),
              Text('By continuing you agree to the Terms of Service & Privacy Policy', textAlign: TextAlign.center, style: AppTheme.sans(11, color: Neutral.c400)),
            ],
          ),
        ),
      ),
    );
  }
}
