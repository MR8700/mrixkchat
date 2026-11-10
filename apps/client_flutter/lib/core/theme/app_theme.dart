import 'package:flutter/material.dart';

/// Design system: "Luminous Sovereign Network"
/// Refined High-Tech Minimalism, Prismatic Glass & Ambient Diffused Glows.
/// Friendly, reassuring user-facing terminology without technical friction.
class AppTheme {
  // Primary Palette
  static const Color surfaceWarm = Color(0xFFEEF2F6); // Soft slate-tinted base ground for clear contrast
  static const Color cardBg = Color(0xFFFFFFFF); // Pure White elevated container
  static const Color primary = Color(0xFF0043B8); // Electric Kinetic Blue
  static const Color primaryContainer = Color(0xFF245BDB); // Bright Azure
  static const Color primarySoft = Color(0xFFE2E8F0);
  
  // Secondary / Cryptographic Integrity Palette
  static const Color secondary = Color(0xFF006B5F); // Mineral Turquoise
  static const Color secondaryGlow = Color(0xFF20B8A5); // Luminous Mint
  static const Color secondaryLight = Color(0xFFE6F8F5);
  static const Color secondaryFixed = Color(0xFF74F8E3);
  
  // Neutral Typography & Borders
  static const Color onSurface = Color(0xFF0F172A); // Midnight Slate (deep contrast)
  static const Color onSurfaceVariant = Color(0xFF475569); // Crisp Cool Slate
  static const Color borderSubtle = Color(0xFFCBD5E1); // Clear, well-defined contour border
  
  // Status Colors
  static const Color statusGreen = Color(0xFF10B981); // Verified & Online
  static const Color statusGreenSoft = Color(0xFFECFDF5);
  static const Color statusCoral = Color(0xFFFF806E); // Burner / Ephemeral
  static const Color statusAmber = Color(0xFFF59E0B);

  // Dark Mode Counterparts
  static const Color darkBackground = Color(0xFF0D131D);
  static const Color darkCard = Color(0xFF151D2A);
  static const Color darkBorder = Color(0xFF222E42);
  static const Color darkOnSurface = Color(0xFFF1F5F9);
  static const Color darkOnSurfaceVariant = Color(0xFF94A3B8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: surfaceWarm,
      colorScheme: const ColorScheme.light(
        primary: primary,
        primaryContainer: primaryContainer,
        secondary: secondary,
        secondaryContainer: secondaryLight,
        surface: cardBg,
        onSurface: onSurface,
        onSurfaceVariant: onSurfaceVariant,
        outline: borderSubtle,
      ),
      fontFamily: 'Roboto',
      fontFamilyFallback: const [
        'Noto Color Emoji',
        'Apple Color Emoji',
        'Segoe UI Emoji',
        'sans-serif',
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWarm,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryContainer,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: primaryContainer,
        secondary: secondaryGlow,
        surface: darkCard,
        onSurface: darkOnSurface,
        onSurfaceVariant: darkOnSurfaceVariant,
        outline: darkBorder,
      ),
      fontFamily: 'Roboto',
      fontFamilyFallback: const [
        'Noto Color Emoji',
        'Apple Color Emoji',
        'Segoe UI Emoji',
        'sans-serif',
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        foregroundColor: darkOnSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
    );
  }
}
