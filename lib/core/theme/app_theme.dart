import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    final textTheme = GoogleFonts.manropeTextTheme(base.textTheme);

    return base.copyWith(
      textTheme: textTheme,
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF7C5CFF),
        secondary: const Color(0xFF2FE6A6),
        surface: const Color(0xFF12131A),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
      scaffoldBackgroundColor: const Color(0xFF0E0F14),
      cardTheme: const CardThemeData(
        color: Color(0xFF141622),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
    );
  }
}
