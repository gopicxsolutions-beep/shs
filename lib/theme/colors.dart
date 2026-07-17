import 'package:flutter/material.dart';

/// Brand: deep emerald (growth/trust) + warm marigold (prosperity).
class Brand {
  static const c50 = Color(0xFFEEFDF6);
  static const c100 = Color(0xFFD6F9E8);
  static const c200 = Color(0xFFAEF1D3);
  static const c300 = Color(0xFF74E3B6);
  static const c400 = Color(0xFF3ECB98);
  static const c500 = Color(0xFF18AB7C);
  static const c600 = Color(0xFF0E8A66);
  static const c700 = Color(0xFF0D6F55);
  static const c800 = Color(0xFF0B5745);
  static const c900 = Color(0xFF0A4A3B);
  static const c950 = Color(0xFF042E24);
}

class Gold {
  static const c50 = Color(0xFFFFFAEB);
  static const c100 = Color(0xFFFEF0C7);
  static const c200 = Color(0xFFFDE08A);
  static const c300 = Color(0xFFFBCA4D);
  static const c400 = Color(0xFFF9AE24);
  static const c500 = Color(0xFFF2900D);
  static const c600 = Color(0xFFD66C08);
  static const c700 = Color(0xFFB24D0B);
  static const c800 = Color(0xFF913C10);
  static const c900 = Color(0xFF783210);
}

class Neutral {
  static const c50 = Color(0xFFF5F7F7);
  static const c100 = Color(0xFFE8ECEC);
  static const c200 = Color(0xFFD3DAD9);
  static const c300 = Color(0xFFADBAB8);
  static const c400 = Color(0xFF82938F);
  static const c500 = Color(0xFF647873);
  static const c600 = Color(0xFF4F605C);
  static const c700 = Color(0xFF414E4B);
  static const c800 = Color(0xFF38423F);
  static const c900 = Color(0xFF202826);
  static const c950 = Color(0xFF0F1413);
}

/// Semantic accents used sparingly (sky/rose/violet) for tones beyond brand/gold.
class Accent {
  static const sky50 = Color(0xFFF0F9FF);
  static const sky600 = Color(0xFF0284C7);
  static const rose50 = Color(0xFFFFF1F2);
  static const rose600 = Color(0xFFE11D48);
  static const violet50 = Color(0xFFF5F3FF);
  static const violet100 = Color(0xFFEDE9FE);
  static const violet600 = Color(0xFF7C3AED);
  static const emerald50 = Color(0xFFECFDF5);
  static const emerald700 = Color(0xFF047857);
  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber600 = Color(0xFFD97706);
  static const amber700 = Color(0xFFB45309);
  static const amber800 = Color(0xFF92400E);
  static const red50 = Color(0xFFFEF2F2);
  static const red100 = Color(0xFFFEE2E2);
  static const red500 = Color(0xFFEF4444);
  static const red600 = Color(0xFFDC2626);
  static const red700 = Color(0xFFB91C1C);
}

const cardShadow = [
  BoxShadow(color: Color(0x0A0F1413), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x1A0F1413), blurRadius: 24, offset: Offset(0, 8), spreadRadius: -8),
];

const navShadow = [
  BoxShadow(color: Color(0x0F0F1413), blurRadius: 24, offset: Offset(0, -4)),
];
