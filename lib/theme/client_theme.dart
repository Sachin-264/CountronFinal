import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientTheme {
  ClientTheme._();

  // --- PREMIUM COLORS ---
  static const Color primaryColor = Color(0xFF2563EB); // Thoda vibrant Royal Blue
  static const Color secondaryColor = Color(0xFFEC4899); // Pink accent (Branding ke liye)

  static const Color background = Color(0xFFF0F4F8); // Ultra Light Blue-Grey (Premium BG)
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF10B981);

  // === FIX: Add missing colors referenced in ClientLayout ===
  static const Color darkText = Color(0xFF1E293B); // Slate 800 (Used for dark sidebar background)
  static const Color textDark = Color(0xFF1E293B); // Slate 800
  static const Color textLight = Color(0xFF64748B); // Slate 500
  static Color shadowColor = primaryColor.withOpacity(0.15); // Used for general shadows
  // =========================================================

  // === GRADIENTS ===
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryColor, Color(0xFF4A90E2)], // primaryColor to a lighter blue accent
    stops: [0.0, 1.0],
  );

  // 🔑 FIX: Added missing secondaryGradient for the "New Test" button
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryColor, Color(0xFFF06292)], // Pink to Lighter Pink
    stops: [0.0, 1.0],
  );
  // ===============================================================

  // 🔑 NEW: Define the logoStyle for the app logo structure
  static TextStyle get logoStyle => GoogleFonts.greatVibes(
    fontWeight: FontWeight.w700,
  );

  // --- TEXT THEME (Montserrat Based) ---
  static TextTheme _buildTextTheme() {
    final base = GoogleFonts.montserratTextTheme();

    return base.copyWith(
      displayLarge: GoogleFonts.montserrat(
          fontSize: 32, fontWeight: FontWeight.bold, color: textDark, letterSpacing: -0.5
      ),
      displayMedium: GoogleFonts.montserrat(
          fontSize: 24, fontWeight: FontWeight.bold, color: textDark, letterSpacing: -0.5
      ),
      titleLarge: GoogleFonts.montserrat(
          fontSize: 20, fontWeight: FontWeight.w600, color: textDark
      ),
      bodyLarge: GoogleFonts.montserrat(
          fontSize: 16, fontWeight: FontWeight.w500, color: textDark
      ),
      bodyMedium: GoogleFonts.montserrat(
          fontSize: 14, fontWeight: FontWeight.w400, color: textLight
      ),
      labelLarge: GoogleFonts.montserrat(
          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white
      ),
    );
  }

  // --- GET THEME DATA ---
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: background,

      // Colors
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surface,
        background: background,
        error: error,
        onPrimary: Colors.white,
        onSurface: textDark,
      ),

      // Fonts
      textTheme: _buildTextTheme(),

      // Card Theme (Clean & Soft Shadow)
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0, // Flat style with shadow via decoration usually
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textDark),
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: textDark, size: 24),
    );
  }
}