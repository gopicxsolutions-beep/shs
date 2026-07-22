import 'package:flutter/material.dart';
import '../l10n/gen/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import 'app_button.dart';

/// Friendly fallback shown in place of Flutter's default red/gray error
/// screens — used by both [ErrorWidget.builder] (a widget threw during
/// build) and the router's `errorBuilder` (no route matched).
class AppErrorScreen extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  // Defaults to "Go to Home" (this screen's original and still most common
  // use — widget-build errors, unmatched routes). Pass this to relabel the
  // button for call sites where `onRetry` does something other than
  // navigate home, e.g. the profile-load-error screen's "Retry" action.
  final String? retryLabel;
  const AppErrorScreen({super.key, required this.title, required this.message, this.onRetry, this.retryLabel});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Neutral.c50,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: Accent.red50, borderRadius: BorderRadius.circular(24)),
                  child: Icon(Icons.error_outline_rounded, color: Accent.red600, size: 30),
                ),
                const SizedBox(height: 20),
                Text(title, textAlign: TextAlign.center, style: AppTheme.display(18)),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
                if (onRetry != null) ...[
                  const SizedBox(height: 20),
                  // Nullable, not `!`: this is the app's catch-all error
                  // fallback (widget-build errors, unmatched routes) and can
                  // in principle render before/without full localization
                  // wiring — fall back to English rather than crash here of
                  // all places.
                  AppButton(label: retryLabel ?? AppLocalizations.of(context)?.errorGoHome ?? 'Go to Home', onPressed: onRetry),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
