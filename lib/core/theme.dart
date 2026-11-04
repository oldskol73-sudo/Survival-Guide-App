// Dark forest-green theme: near-black green page, deep green cards, soft green accent, red for emergencies.
// Palette sampled from the reference image. Every text/background pair is >= 4.5:1 (WCAG AA).

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

class AppTheme {
  static const bg = Color(0xFF0A1511); // page
  static const card = Color(0xFF123428); // cards and tiles
  static const outline = Color(0xFF245140);
  static const text = Color(0xFFEAF2EC); // ~15:1 on bg
  static const muted = Color(0xFF9DB8A8); // ~8:1 on bg
  static const accent = Color(0xFFEDE7DB); // cream/beige accent: icons, headings, buttons, progress (~14:1 on bg)
  static const accentSoft = Color(0xFF1F4D3A); // selected chips, progress track
  static const warn = Color(0xFFE6B04A); // ~9:1 on bg
  static const danger = Color(0xFFFF7A6E); // red as TEXT/ICON on dark, ~7:1 on bg
  static const sos = Color(0xFFB3201A); // red as a FILL under white text, ~7:1
  static const ok = Color(0xFF6FCF8D);

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      surface: bg,
      primary: accent,
      onPrimary: bg,
      secondary: accent,
      error: danger,
      onSurface: text,
      outline: outline,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardTheme: const CardThemeData(color: card, elevation: 0, margin: EdgeInsets.symmetric(vertical: 4), shape: RoundedRectangleBorder(side: BorderSide(color: outline), borderRadius: BorderRadius.all(Radius.circular(16)))),
      appBarTheme: const AppBarTheme(backgroundColor: bg, foregroundColor: text, elevation: 0, scrolledUnderElevation: 0),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: card, indicatorColor: accentSoft),
      chipTheme: const ChipThemeData(backgroundColor: card, selectedColor: accentSoft, side: BorderSide(color: outline), labelStyle: TextStyle(color: text), checkmarkColor: accent),
      inputDecorationTheme: const InputDecorationTheme(filled: true, fillColor: card, border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
      dividerColor: outline,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: text, fontSize: 16, height: 1.45),
        bodySmall: TextStyle(color: muted, fontSize: 13),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.w700),
      ),
    );
  }
}
