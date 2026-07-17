import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static TextStyle display(double size, {FontWeight weight = FontWeight.w700, Color? color}) =>
      TextStyle(fontFamily: 'Roboto', fontSize: size, fontWeight: weight, color: color ?? Neutral.c900);

  static TextStyle sans(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
      TextStyle(fontFamily: 'Roboto', fontSize: size, fontWeight: weight, color: color ?? Neutral.c900);

  static ThemeData get data {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: Neutral.c50,
      colorScheme: ColorScheme.fromSeed(seedColor: Brand.c600, primary: Brand.c600),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: display(34),
        headlineMedium: display(24),
        titleLarge: display(17),
      ),
    );
  }
}
