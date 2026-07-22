import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';

/// Pushes a full-screen camera QR scanner and returns the first decoded
/// value, or null if the user backs out. Shared by Meeting check-in and
/// Payments QR.
///
/// Camera access can fail in more ways than a clean "permission denied":
/// some embedded/sandboxed browser contexts block `getUserMedia()` without
/// ever resolving or rejecting the promise, which would otherwise hang the
/// scanner forever with nothing but a black screen (found by live-testing
/// this in exactly such an environment — the tool this app was built in
/// blocks camera access outright). Two independent safety nets handle
/// this: an "Enter manually" exit is visible in the app bar from the
/// instant the page opens (not gated on any camera event firing), and a
/// timeout shows a friendly fallback message if the camera hasn't
/// initialized within a few seconds even without an explicit error.
Future<String?> showQrScanner(BuildContext context, {required String title, required String instructions}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (context) => _QrScannerPage(title: title, instructions: instructions)),
  );
}

class _QrScannerPage extends StatefulWidget {
  final String title;
  final String instructions;
  const _QrScannerPage({required this.title, required this.instructions});
  @override
  State<_QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<_QrScannerPage> {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _handled = false;
  bool _timedOut = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_controller.value.isInitialized) setState(() => _timedOut = true);
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || !mounted || capture.barcodes.isEmpty) return;
    final code = capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  // Nullable, not `!` throughout this file: falls back to English rather
  // than crash if this ever renders without localization delegates wired
  // up (this app's other l10n-aware shared widgets follow the same
  // defensive pattern — see page_header.dart's doc comment for why).
  String _errorMessage(MobileScannerException error) {
    final l10n = AppLocalizations.of(context);
    return switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => l10n?.qrPermissionDenied ?? 'Camera permission was denied.',
      MobileScannerErrorCode.unsupported => l10n?.qrUnsupported ?? "Scanning isn't supported on this device.",
      _ => l10n?.qrCameraUnavailable ?? 'Camera not available.',
    };
  }

  Widget _fallback(String message) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white70, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Colors.white70)),
            const SizedBox(height: 8),
            Text(l10n?.qrManualFallbackHint ?? 'You can still enter details manually.', textAlign: TextAlign.center, style: AppTheme.sans(12, color: Colors.white54)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                _handled = true;
                Navigator.of(context).pop();
              },
              child: Text(l10n?.qrEnterManually ?? 'Enter manually instead'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // This is a plain Flutter `AppBar` (not the app's own
        // `PageHeader`), pushed imperatively via `Navigator.push` rather
        // than a registered `GoRoute` — so neither round 26's route smoke
        // test nor round 27's text-scale stress test (both GoRouter-only)
        // ever exercised it. Same fixed-height-chrome shape `page_header.
        // dart` already fixes: `AppBar`'s toolbar height is fixed (56 by
        // default), and a long localized title (e.g. "उपस्थिति QR स्कैन
        // करें") next to the "Manual entry" action button can wrap to 2
        // lines at a scaled-up accessibility text size and overflow that
        // fixed height. FittedBox scales the title down to fit instead.
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _handled = true;
              Navigator.of(context).pop();
            },
            child: Text(l10n?.qrManualEntry ?? 'Manual entry', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) => IconButton(
              icon: Icon(state.torchState == TorchState.on ? Icons.flash_on_rounded : Icons.flash_off_rounded),
              onPressed: state.torchState == TorchState.unavailable ? null : () => _controller.toggleTorch().catchError((_) {}),
              tooltip: state.torchState == TorchState.on ? (l10n?.qrTurnOffFlashlight ?? 'Turn off flashlight') : (l10n?.qrTurnOnFlashlight ?? 'Turn on flashlight'),
            ),
          ),
        ],
      ),
      body: _timedOut
          ? _fallback(l10n?.qrTakingTooLong ?? 'Camera is taking too long to start.')
          : Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) => _fallback(_errorMessage(error)),
                ),
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2), borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 32,
                  left: 24,
                  right: 24,
                  child: Text(widget.instructions, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Colors.white)),
                ),
              ],
            ),
    );
  }
}
