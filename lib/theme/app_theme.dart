// [REPLACE] lib/theme/app_theme.dart

import 'dart:ui'; // Glassmorphic ke liye
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// === Glassmorphic Container Widget ===
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final double blur;
  final double opacity;

  const GlassmorphicContainer({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.blur = 10,
    this.opacity = 0.1,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final glassColor = isDark
        ? AppTheme.darkText.withOpacity(opacity + 0.1)
        : AppTheme.background.withOpacity(opacity);

    final borderColor = isDark
        ? AppTheme.borderGrey.withOpacity(0.2)
        : AppTheme.background.withOpacity(0.5);

    final shadowColor = isDark ? Colors.black.withOpacity(0.1) : AppTheme.shadowColor;

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: glassColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: shadowColor,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}


// === AAPKI THEME CLASS ===
class AppTheme {
  AppTheme._();

  // --- COUNTDOWN BRAND COLORS ---
  static const Color primaryBlue = Color(0xFF1B78D3);
  static const Color accentBlue = Color(0xFF4A90E2);

  static const Color darkText = Color(0xFF0F172A); // Slate 900
  static const Color bodyText = Color(0xFF64748B); // Slate 500
  static const Color lightGrey = Color(0xFFF8FAFC); // Slate 50
  static const Color borderGrey = Color(0xFFE2E8F0); // Slate 300
  static const Color background = Color(0xFFFFFFFF);
  static Color shadowColor = const Color(0xFF1B78D3).withOpacity(0.1);
  static const Color accentGreen = Color(0xFF10B981); // 'Online' status
  static const Color accentRed = Color(0xFFEF4444); // Errors ke liye
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color accentYellow = Color(0xFFF59E0B);


  // --- GRADIENTS ---
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBlue, primaryBlue],
    stops: [0.0, 1.0],
  );

  // --- TEXT STYLES (MODERN FONTS) ---

  // [KEPT] Yeh hamara main 'Logo/Display' font hai
  static TextStyle get logoStyle => GoogleFonts.bebasNeue(
      letterSpacing: 0.5
  );


  // [MODIFIED] Secondary font ab 'Montserrat' hai
  static TextStyle get _baseTextStyle => GoogleFonts.montserrat();


  static TextStyle get headline1 => _baseTextStyle.copyWith(
      fontSize: 28, fontWeight: FontWeight.w800, color: darkText);
  static TextStyle get headline2 => _baseTextStyle.copyWith(
      fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white);
  static TextStyle get bodyText1 => _baseTextStyle.copyWith(
      fontSize: 16, fontWeight: FontWeight.w500, color: bodyText);
  static TextStyle get labelText => _baseTextStyle.copyWith(
      fontSize: 14, fontWeight: FontWeight.w600, color: darkText);
  static TextStyle get buttonText => _baseTextStyle.copyWith(
      fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white);

  static TextStyle get stylizedHeading => _baseTextStyle.copyWith(
      fontWeight: FontWeight.w300,
      letterSpacing: 1.5,
      color: darkText
  );

  // --- UPDATED: TextTheme object ---
  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      // 'Bebas Neue' Font (LogoStyle)
      displayLarge: logoStyle.copyWith(fontSize: 48, fontWeight: FontWeight.w600, color: darkText),
      headlineMedium: logoStyle.copyWith(fontSize: 32, fontWeight: FontWeight.w600, color: darkText), // Dialog titles
      headlineSmall: logoStyle.copyWith(fontSize: 28, fontWeight: FontWeight.w600, color: darkText), // Details/Edit panel titles
      titleLarge: logoStyle.copyWith(fontSize: 24, fontWeight: FontWeight.w600, color: darkText), // Centered dialog titles

      // 'Montserrat' Font (BaseStyle)
      titleMedium: _baseTextStyle.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: darkText),
      bodyLarge: bodyText1, // w500
      bodyMedium: _baseTextStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w400, color: bodyText), // w400
      labelMedium: _baseTextStyle.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: bodyText), // w500
    );
  }

  // --- NAYA: LIGHT THEME ---
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightGrey,
    primaryColor: primaryBlue,
    textTheme: _buildTextTheme(ThemeData.light().textTheme),
    colorScheme: const ColorScheme.light(
      primary: primaryBlue,
      secondary: accentGreen,
      error: accentRed,
      surface: background,
      onSurface: darkText,
      background: lightGrey,
      onBackground: darkText,
    ),
  );

  // --- NAYA: DARK THEME ---
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkText, // Dark background
    primaryColor: primaryBlue,
    textTheme: _buildTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: lightGrey, // Default text color dark mode mein
      displayColor: lightGrey,
    ),
    colorScheme: const ColorScheme.dark(
      primary: primaryBlue,
      secondary: accentGreen,
      error: accentRed,
      surface: Color(0xFF1E293B), // Dark card
      onSurface: lightGrey, // Dark mode text
      background: darkText,
      onBackground: lightGrey,
    ),
  );

  // --- PADDING & BORDERS ---
  static const double defaultPadding = 16.0;
  static final BorderRadius defaultBorderRadius = BorderRadius.circular(12.0);
}