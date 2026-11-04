// OLED pure-black theme. On OLED panels black pixels are off, so a black UI draws noticeably
// less power than a dark-grey one. Accent is a single warm amber that keeps 4.5:1+ contrast.

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

class OledTheme {
  static const black = Color(0xFF000000);
  static const surface = Color(0xFF0A0A0A);
  static const outline = Color(0xFF2A2A2A);
  static const text = Color(0xFFE8E6E1); // ~16:1 on black
  static const muted = Color(0xFF9C9A94); // ~7:1 on black
  static const amber = Color(0xFFFFB347); // accent, ~11:1 on black
  static const danger = Color(0xFFFF6B5A); // ~6.5:1 on black
  static const ok = Color(0xFF7BD88F);

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      surface: black,
      primary: amber,
      onPrimary: black,
      secondary: amber,
      error: danger,
      onSurface: text,
      outline: outline,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: black,
      canvasColor: black,
      cardTheme: const CardThemeData(color: surface, elevation: 0, shape: RoundedRectangleBorder(side: BorderSide(color: outline), borderRadius: BorderRadius.all(Radius.circular(10)))),
      appBarTheme: const AppBarTheme(backgroundColor: black, foregroundColor: text, elevation: 0, scrolledUnderElevation: 0),
      navigationBarTheme: const NavigationBarThemeData(backgroundColor: black, indicatorColor: Color(0xFF2B2111)),
      dividerColor: outline,
      // Fewer animations = fewer frames rendered = less GPU wake time.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: text, fontSize: 16, height: 1.45),
        bodySmall: TextStyle(color: muted, fontSize: 13),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.w600),
      ),
    );
  }
}
