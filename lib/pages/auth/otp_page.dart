import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../routes/paths.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';
import '../../widgets/async_state.dart';
import '../../widgets/input_formatters.dart';

class OtpPage extends StatefulWidget {
  final String? phone;
  const OtpPage({super.key, this.phone});
  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _digits = List.generate(6, (_) => TextEditingController());
  final _focus = List.generate(6, (_) => FocusNode());
  final _authService = AuthService();
  Timer? _timer;
  int _resendSeconds = 30;
  bool _verifying = false;
  bool _resending = false;
  String? _error;

  String get _phone => widget.phone ?? '+91 98765 43210';

  bool get _filled => _digits.every((c) => c.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendSeconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendSeconds <= 1) {
        t.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _digits) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 || _resending || !SupabaseService.isConfigured) return;
    setState(() => _resending = true);
    try {
      await _authService.sendOtp(_phone);
      if (mounted) _startResendTimer();
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _error = isNetworkError(e) ? l10n.asyncErrorNetwork : l10n.otpResendError);
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _submit() async {
    if (!SupabaseService.isConfigured) {
      context.go(Paths.profileSetup);
      return;
    }
    final code = _digits.map((c) => c.text).join();
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await _authService.verifyOtp(_phone, code);
      if (!mounted) return;
      final appState = context.read<AppState>();
      await appState.refreshProfile();
      if (!mounted) return;
      // Replay a deep link the router captured (see
      // AppState.capturePendingDeepLink) only once onboarding is fully
      // clear — if Role Select or SHG approval still needs to run first,
      // `Paths.dashboard` is exactly what this went to before, and the
      // router's own redirect chain takes it from there (Role Select / SHG
      // Approval Pending / Profile Setup as appropriate); the deep link is
      // left captured rather than threaded through those in-between screens.
      final canReplayDeepLink = appState.hasProfile && !appState.needsRoleSelection && !appState.needsShgApproval;
      final deepLink = canReplayDeepLink ? appState.consumePendingDeepLink() : null;
      context.go(deepLink ?? (appState.hasProfile ? Paths.dashboard : Paths.profileSetup));
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _error = isNetworkError(e) ? l10n.asyncErrorNetwork : l10n.otpVerifyError);
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(Icons.sms_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              Text(l10n.otpTitle, style: AppTheme.display(22)),
              const SizedBox(height: 6),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(style: AppTheme.sans(13, color: Neutral.c500), children: [
                  TextSpan(text: l10n.otpSentTo),
                  TextSpan(text: _phone, style: AppTheme.sans(13, weight: FontWeight.w700, color: Neutral.c700)),
                ]),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                // 6 visually-identical, unlabeled boxes: a sighted user infers
                // "this is the OTP" from the title/hint above and the boxes'
                // left-to-right position. A screen reader has no equivalent —
                // without a per-box label it announces 6 indistinguishable
                // "edit box" nodes with no indication they're digits 1-6 of
                // one code. MergeSemantics folds the position label together
                // with the field's own live value (the digit just typed) into
                // a single announced node, instead of ExcludeSemantics (used
                // elsewhere in this codebase for static content) which would
                // silently drop that live value.
                children: List.generate(6, (i) => MergeSemantics(
                    child: Semantics(
                      label: l10n.otpDigitLabel(i + 1),
                      child: SizedBox(
                      width: 44, height: 52,
                      child: TextField(
                        controller: _digits[i],
                        focusNode: _focus[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        textInputAction: i < 5 ? TextInputAction.next : TextInputAction.done,
                        inputFormatters: [OtpBoxFormatter(index: i, controllers: _digits, focusNodes: _focus, onFilled: () => setState(() {}))],
                        maxLength: 1,
                        style: AppTheme.sans(18, weight: FontWeight.w700),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Neutral.c200)),
                        ),
                        onChanged: (v) {
                          setState(() {});
                          if (v.isNotEmpty && i < 5) _focus[i + 1].requestFocus();
                        },
                      ),
                    ),
                  ),
                )),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppTheme.sans(11, color: Accent.red600)),
              ],
              const SizedBox(height: 20),
              InkWell(
                onTap: _resendSeconds > 0 || _resending ? null : _resend,
                child: Text.rich(
                  TextSpan(style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600), children: [
                    if (_resendSeconds > 0) ...[
                      TextSpan(text: l10n.otpResendIn),
                      TextSpan(text: '00:${_resendSeconds.toString().padLeft(2, '0')}', style: AppTheme.sans(12, color: Neutral.c400, weight: FontWeight.w400)),
                    ] else
                      TextSpan(text: l10n.otpResend),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              AppButton(
                label: _verifying ? l10n.otpVerifying : l10n.otpVerifyContinue,
                fullWidth: true,
                size: ButtonSize.lg,
                onPressed: _filled && !_verifying ? _submit : null,
              ),
              const SizedBox(height: 32),
              Text(l10n.otpDidntReceive, style: AppTheme.sans(11, color: Neutral.c400)),
            ],
          ),
        ),
      ),
    );
  }
}
