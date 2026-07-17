import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../routes/paths.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';
import '../../widgets/app_button.dart';

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
    if (_resendSeconds > 0 || !SupabaseService.isConfigured) return;
    try {
      await _authService.sendOtp(_phone);
      _startResendTimer();
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not resend the code. Please try again.');
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
      context.go(appState.hasProfile ? Paths.dashboard : Paths.profileSetup);
    } catch (_) {
      if (mounted) setState(() => _error = 'Incorrect or expired code. Please try again.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(Icons.sms_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 20),
              Text('Verify OTP', style: AppTheme.display(22)),
              const SizedBox(height: 6),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(style: AppTheme.sans(13, color: Neutral.c500), children: [
                  const TextSpan(text: "We've sent a 6-digit code to "),
                  TextSpan(text: _phone, style: AppTheme.sans(13, weight: FontWeight.w700, color: Neutral.c700)),
                ]),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => SizedBox(
                      width: 44, height: 52,
                      child: TextField(
                        controller: _digits[i],
                        focusNode: _focus[i],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
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
                    )),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: AppTheme.sans(11, color: Accent.red600)),
              ],
              const SizedBox(height: 20),
              InkWell(
                onTap: _resend,
                child: Text.rich(
                  TextSpan(style: AppTheme.sans(12, weight: FontWeight.w700, color: Brand.c600), children: [
                    if (_resendSeconds > 0) ...[
                      const TextSpan(text: 'Resend OTP in '),
                      TextSpan(text: '00:${_resendSeconds.toString().padLeft(2, '0')}', style: AppTheme.sans(12, color: Neutral.c400, weight: FontWeight.w400)),
                    ] else
                      const TextSpan(text: 'Resend OTP'),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              AppButton(
                label: _verifying ? 'Verifying…' : 'Verify & Continue',
                fullWidth: true,
                size: ButtonSize.lg,
                onPressed: _filled && !_verifying ? _submit : null,
              ),
              const Spacer(),
              Text("Didn't receive the code? Check your SMS inbox.", style: AppTheme.sans(11, color: Neutral.c400)),
            ],
          ),
        ),
      ),
    );
  }
}
