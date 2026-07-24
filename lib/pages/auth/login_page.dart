import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../routes/paths.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/async_state.dart';
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

  // Indian mobile numbers are 10 digits starting with 6-9 — landline and
  // other non-mobile numbers use different leading digits. Without this,
  // `_controller.text.length >= 10` alone accepted any 10-digit string (e.g.
  // "0000000000"), enabling "Send OTP" for a number that was never going to
  // receive one — the user only found out after a round trip, surfaced as
  // the same generic loginOtpError shown for a real network failure.
  static final _mobilePattern = RegExp(r'^[6-9]\d{9}$');

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
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _error = isNetworkError(e) ? l10n.asyncErrorNetwork : l10n.loginOtpError);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = _mobilePattern.hasMatch(_controller.text);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Neutral.c50,
      body: SafeArea(
        child: SingleChildScrollView(
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
              // The visible "+91" is a plain sibling Text, not part of the
              // field's own InputDecoration — a screen reader announces it
              // as its own disconnected node ("plus 91") right before an
              // edit box whose only accessible name is a hint that vanishes
              // once typed. MergeSemantics folds that country-code text and
              // an explicit "Mobile" label together with the field's own
              // live value into one announced node (same pattern used for
              // the OTP digit boxes), on the one screen every user without
              // exception passes through.
              MergeSemantics(
                child: Semantics(
                  label: l10n.profileMobile,
                  child: Container(
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
                              if (_mobilePattern.hasMatch(_controller.text) && !_sending) _submit();
                            },
                            decoration: const InputDecoration(border: InputBorder.none, counterText: '', hintText: '98765 43210'),
                            style: AppTheme.sans(14),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    Expanded(child: Text(l10n.loginDataProtected, style: AppTheme.sans(11, color: Brand.c700))),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(l10n.loginTermsAgreement, textAlign: TextAlign.center, style: AppTheme.sans(11, color: Neutral.c400)),
            ],
          ),
        ),
      ),
    );
  }
}
