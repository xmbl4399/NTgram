import 'package:flutter/material.dart';
import 'package:native_tavern/data/models/app_theme_config.dart';

// Re-exported so widgets that already import this file can use `context.neko`
// without an extra import.
export 'package:native_tavern/data/models/app_theme_config.dart'
    show NekoColors, NekoContextX;

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
  static const Color darkBackground =
      Color(0xFF222931); // page bg (grey, not black)
  static const Color darkSurface = Color(0xFF222931); // appbar == bg (fused)
  static const Color darkCard =
      Color(0xFF2A313D); // card / grouped panel surface
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

  // Neko list row heights (transcribed from Nekogram sources):
  //   DialogCell.heightDefault = 70dp  (chat / conversation rows)
  //   TextSettingsCell.subtitle  = 50dp (single-line settings rows)
  static const double chatRowHeight = 70; // Neko DialogCell two-line default
  static const double settingsRowHeight = 50; // Neko TextSettingsCell
  // The 玩法 / AI配置 / 设置 nav pages use a roomier 60dp row with no
  // in-card dividers.
  static const double navPageRowHeight = 60;

  /// The default Neko dark theme.
  ///
  /// Delegates to the config-driven factory ([AppThemeConfig.toThemeData]) so
  /// the app keeps exactly one theme implementation. Kept for callers that
  /// want the default dark Neko look without building a config first.
  static ThemeData get darkTheme => BuiltInThemes.defaultDark.toThemeData();

  /// The default light theme (same single source of truth as [darkTheme]).
  static ThemeData get lightTheme => BuiltInThemes.defaultLight.toThemeData();
}
