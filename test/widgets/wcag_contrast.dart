import 'dart:math' as math;

import 'package:flutter/material.dart';

/// WCAG 2.x relative-luminance contrast ratio between two colors — shared
/// by the badge/button/avatar contrast regression tests, since all three
/// hit the same real color-token failures this session.
double contrastRatio(Color a, Color b) {
  final la = _relativeLuminance(a);
  final lb = _relativeLuminance(b);
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

double _relativeLuminance(Color c) {
  return 0.2126 * _channelLinear(c.r) + 0.7152 * _channelLinear(c.g) + 0.0722 * _channelLinear(c.b);
}

double _channelLinear(double c) => c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
