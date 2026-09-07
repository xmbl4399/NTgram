import 'package:flutter/material.dart';

/// App theme configuration matching Nekogram's dark blue aesthetic.
///
/// NativeTavern originally used a SillyTavern-style purple palette. NTgram
/// re-skins to Neko's deep-blue identity while keeping every programmatic
/// reference (`AppTheme.primaryColor`, `darkBackground`, etc.) working.
class AppTheme {
  // Neko (Telegram fork) accent / brand palette — replaces the purple.
  static const Color primaryColor = Color(0xFF58A3DC); // Neko accent blue
  static const Color secondaryColor = Color(0xFF3498DB);
  static const Color accentColor = Color(0xFF58A3DC); // accent follows Neko blue

  // Neko deep-blue dark theme colors
  static const Color darkBackground = Color(0xFF0E1621); // Neko bg
  static const Color darkSurface = Color(0xFF17212B); // Neko panel
  static const Color darkCard = Color(0xFF1F2837); // Neko card (panel +1)
  static const Color darkDivider = Color(0xFF1E2A36);

  // Text colors
  static const Color textPrimary = Color(0xFFE4E4E7);
  static const Color textSecondary = Color(0xFF7E8A98); // Neko secondary
  static const Color textMuted = Color(0xFF5C6B7A);

  // Chat bubble colors (Neko)
  static const Color userBubble = Color(0xFF2B5278); // Neko out-bubble blue
  static const Color assistantBubble = Color(0xFF17212B); // Neko in-bubble panel
  static const Color systemBubble = Color(0xFF4B5563);

  // Neko GlassTab (floating bottom bar) palette — fallback to messagePanelSend.
  static const Color glassTabSelected = Color(0xFF58A3DC); // accent blue
  static const Color glassTabSelectedText = Color(0xFFFFFFFF); // bold white
  static const Color glassTabUnselected = Color(0xFF8E94A2); // grey
  static const Color glassTabBackground = Color(0xE6181D29); // translucent
  static const Color glassTabBorder = Color(0xFF343B4C);
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