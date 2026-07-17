import 'package:flutter/material.dart';
import '../theme/colors.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? ringColor;
  const AppAvatar({super.key, required this.name, this.size = 40, this.ringColor});

  static const _palette = [
    (Brand.c100, Brand.c700),
    (Gold.c100, Gold.c700),
    (Accent.sky50, Accent.sky600),
    (Accent.rose50, Accent.rose600),
    (Accent.violet100, Accent.violet600),
  ];

  int _hash(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((p) => p.isNotEmpty ? p[0] : '').join().toUpperCase();
    final (bg, fg) = _palette[_hash(name) % _palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: ringColor != null ? Border.all(color: ringColor!, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(initials, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: size * 0.36)),
    );
  }
}
