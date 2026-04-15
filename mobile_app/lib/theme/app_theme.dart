import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PetVisionTheme {
  static const Color backgroundLight = Colors.white; // True white minimal bg
  static const Color primaryText = Color(0xFF111827); // Gray-900 (Softer than pitch black)
  static final Color secondaryText = Colors.grey.shade600; 

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF10B981)), // Emerald Green
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: primaryText),
        titleTextStyle: GoogleFonts.inter(
          fontWeight: FontWeight.w700, 
          color: primaryText, 
          fontSize: 18,
          letterSpacing: -0.5
        ),
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w800, color: primaryText, letterSpacing: -1),
        displayMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700, color: primaryText, letterSpacing: -0.5),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: primaryText, letterSpacing: -0.5),
        bodyLarge: GoogleFonts.inter(fontSize: 15, color: primaryText, fontWeight: FontWeight.w500, height: 1.4),
        bodyMedium: GoogleFonts.inter(fontSize: 13, color: secondaryText, fontWeight: FontWeight.w400, height: 1.4),
        labelLarge: GoogleFonts.inter(fontSize: 12, color: secondaryText, fontWeight: FontWeight.w700, letterSpacing: 1.2),
      ),
    );
  }
}
