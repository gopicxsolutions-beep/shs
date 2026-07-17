import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';

/// Wraps a [Future] with consistent loading / error+retry / data states.
/// Shared across every data-backed feature screen (Savings, Loans, ...) so
/// each repository-backed page doesn't hand-roll its own FutureBuilder.
class AppAsyncBuilder<T> extends StatefulWidget {
  final Future<T> Function() future;
  final Widget Function(BuildContext context, T data) builder;
  final String errorMessage;
  const AppAsyncBuilder({
    super.key,
    required this.future,
    required this.builder,
    this.errorMessage = 'Something went wrong. Please try again.',
  });

  @override
  State<AppAsyncBuilder<T>> createState() => AppAsyncBuilderState<T>();
}

class AppAsyncBuilderState<T> extends State<AppAsyncBuilder<T>> {
  late Future<T> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.future();
  }

  Future<void> reload() {
    final next = widget.future();
    setState(() => _future = next);
    return next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.error_outline_rounded, color: Accent.red500, size: 32),
                const SizedBox(height: 12),
                Text(widget.errorMessage, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
                const SizedBox(height: 12),
                TextButton(onPressed: reload, child: const Text('Retry')),
              ]),
            ),
          );
        }
        return widget.builder(context, snapshot.data as T);
      },
    );
  }
}

/// A simple centered empty-state block used inside list screens.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const AppEmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 32, color: Neutral.c300),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: AppTheme.sans(13, color: Neutral.c500)),
      ]),
    );
  }
}
