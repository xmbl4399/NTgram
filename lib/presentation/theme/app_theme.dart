import 'package:flutter/material.dart';

/// App theme configuration matching Nekogram's AMOLED dark aesthetic.
///
/// Values are transcribed from Neko's built-in `night.attheme`:
///   actionBarDefault            #232326  (top bar grey)
///   windowBackgroundWhite       #181819  (card / panel)
///   chat_messagePanelSend       #229AF0  (accent blue)
///   chat_messagePanelBackground #1E1E1F  (input bar)
///   windowBackgroundGray        #000000  (scroll background)
/// NativeTavern originally used a purple palette; NTgram re-skins to this
/// Neko identity while keeping every programmatic reference working.
class AppTheme {
  // Neko accent / brand palette (chat_messagePanelSend #229AF0).
  static const Color primaryColor = Color(0xFF229AF0);
  static const Color secondaryColor = Color(0xFF3498DB);
  static const Color accentColor = Color(0xFF229AF0);

  // Neko dark theme colors, transcribed from the real Nekogram night UI
  // (screenshot on device, verified pixel values):
  //   page background (windowBackgroundGray area)  #222931  grey-blue
  //   rounded card / grouped panel surface          #2A313D  one step lighter
  //   top bar fuses with the page background (no hard black / no bar seam)
  //   accent  #229AF0 (chat_messagePanelSend) unchanged.
  static const Color darkBackground = Color(0xFF222931); // page bg (grey, not black)
  static const Color darkSurface = Color(0xFF222931); // appbar == bg (fused)
  static const Color darkCard = Color(0xFF2A313D); // card / grouped panel surface
  static const Color darkDivider = Color(0xFF37404D); // subtle row separator

  // Text colors
  static const Color textPrimary = Color(0xFFE9EDF3); // title text (near-white)
  static const Color textSecondary = Color(0xFF8A8A8E); // grey secondary
  static const Color textMuted = Color(0xFF5E6B7A);

  // Chat bubble colors (Neko)
  static const Color userBubble = Color(0xFF1F4E79); // Neko out-bubble blue
  static const Color assistantBubble = Color(0xFF2A313D); // in-bubble card
  static const Color systemBubble = Color(0xFF4B5563);

  // Neko GlassTab (floating bottom bar) — fallback to messagePanelSend.
  static const Color glassTabSelected = Color(0xFF229AF0); // accent blue
  static const Color glassTabSelectedText = Color(0xFFFFFFFF); // bold white
  static const Color glassTabUnselected = Color(0xFF8A8A8E); // grey
  static const Color glassTabBackground = Color(0xE62A313D); // translucent grey
  static const Color glassTabBorder = Color(0xFF2E3A47);
  static const double glassTabSelectedAlpha = 0.09; // Neko 9% alpha capsule

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: darkSurface,
        onSurface: textPrimary,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
      ),
      scaffoldBackgroundColor: darkBackground,
      cardColor: darkCard,
      dividerColor: darkDivider,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textSecondary,
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMuted,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: glassTabSelected.withValues(alpha: glassTabSelectedAlpha),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: glassTabSelectedText,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            );
          }
          return const TextStyle(color: glassTabUnselected, fontSize: 12);
        }),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: textMuted,
          fontSize: 12,
        ),
      ),
    );
  }

  static ThemeData get lightTheme {
    // Light theme for users who prefer it
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: Colors.white,
        onSurface: Colors.grey[900]!,
      ),
      scaffoldBackgroundColor: Colors.grey[50],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[900],
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}