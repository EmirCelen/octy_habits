import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      textTheme: GoogleFonts.interTextTheme(base.textTheme),
      colorScheme: base.colorScheme.copyWith(
        primary: const Color(0xFF7C5CFF),
        secondary: const Color(0xFF2FE6A6),
        surface: const Color(0xFF12131A),
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
