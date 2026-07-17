import 'package:flutter/material.dart';
import '../../layout/page_header.dart';
import '../../theme/app_theme.dart';
import '../../theme/colors.dart';

class ComingSoonPage extends StatelessWidget {
  final String title;
  const ComingSoonPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageHeader(title: title),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 96),
          child: Text('This screen is under construction', textAlign: TextAlign.center, style: AppTheme.sans(13, weight: FontWeight.w600, color: Neutral.c500)),
        ),
      ),
    );
  }
}
