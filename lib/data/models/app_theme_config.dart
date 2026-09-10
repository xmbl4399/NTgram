import 'dart:convert';
import 'package:flutter/material.dart';

/// Custom theme configuration
class AppThemeConfig {
  final String id;
  final String name;
  final bool isDark;
  final String primaryColor;
  final String accentColor;
  final String backgroundColor;
  final String surfaceColor;
  final String cardColor;
  final String textPrimaryColor;
  final String textSecondaryColor;
  final String dividerColor;
  final bool isBuiltIn;

  const AppThemeConfig({
    required this.id,
    required this.name,
    this.isDark = true,
    required this.primaryColor,
    required this.accentColor,
    required this.backgroundColor,
    required this.surfaceColor,
    required this.cardColor,
    required this.textPrimaryColor,
    required this.textSecondaryColor,
    required this.dividerColor,
    this.isBuiltIn = false,
  });

  /// Convert hex string to Color
  static Color hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  /// Convert Color to hex string
  static String colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Get Flutter Color objects
  Color get primary => hexToColor(primaryColor);
  Color get accent => hexToColor(accentColor);
  Color get background => hexToColor(backgroundColor);
  Color get surface => hexToColor(surfaceColor);
  Color get card => hexToColor(cardColor);
  Color get textPrimary => hexToColor(textPrimaryColor);
  Color get textSecondary => hexToColor(textSecondaryColor);
  Color get divider => hexToColor(dividerColor);

  /// Generate a ThemeData from this config.
  ///
  /// This is the single source of truth for the runtime theme — `app.dart`
  /// feeds `activeTheme.toThemeData()` into `MaterialApp`. Every component
  /// theme below is derived from the config colors, so light and custom themes
  /// stay coherent instead of inheriting hardcoded Neko-dark values.
  ///
  /// `AppTheme.darkTheme` delegates here as well (see `app_theme.dart`).
  ThemeData toThemeData() {
    final colorScheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: isDark ? Colors.white : Colors.black,
      secondary: accent,
      onSecondary: isDark ? Colors.white : Colors.black,
      error: Colors.red,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
    );

    // Neko panels are flat: cards, dialogs, sheets and menus all sit on the
    // same `card` surface with zero elevation and no surface tint.
    final panel = card;
    final onPanel = textPrimary;

    final sheetShape = RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: panel,
      cardColor: panel,
      dividerColor: divider,
      extensions: <ThemeExtension<dynamic>>[NekoColors.fromConfig(this)],
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: TextStyle(
          color: onPanel,
          fontSize: 17,
          fontWeight: FontWeight.w500,
        ),
        contentTextStyle: TextStyle(
          color: textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        modalBackgroundColor: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: divider,
        shape: sheetShape,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel,
        contentTextStyle: TextStyle(color: onPanel, fontSize: 13),
        actionTextColor: accent,
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        showCloseIcon: false,
        dismissDirection: DismissDirection.down,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panel,
        selectedColor: accent.withValues(alpha: isDark ? 0.28 : 0.16),
        disabledColor: divider,
        side: BorderSide(color: divider, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(color: onPanel, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: onPanel, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        showCheckmark: false,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: divider, width: 0.5),
        ),
        textStyle: TextStyle(color: onPanel, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: accent,
        unselectedLabelColor: textSecondary,
        indicatorColor: accent,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13),
        overlayColor: WidgetStatePropertyAll(
          accent.withValues(alpha: 0.08),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: divider,
        circularTrackColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: onPanel,
        iconColor: textSecondary,
        dense: true,
        visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
        minVerticalPadding: 0,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        minTileHeight: 40,
      ),
      popupMenuTheme: PopupMenuThemeData(
        menuPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
        textStyle: TextStyle(color: onPanel, fontSize: 13),
        color: panel,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 2,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
        activeTrackColor: accent,
        inactiveTrackColor: divider,
        thumbColor: accent,
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
      ),
      switchTheme: SwitchThemeData(
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : divider,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textSecondary),
        titleLarge: TextStyle(color: textPrimary),
        titleMedium: TextStyle(color: textPrimary),
        titleSmall: TextStyle(color: textSecondary),
      ),
    );
  }

  AppThemeConfig copyWith({
    String? id,
    String? name,
    bool? isDark,
    String? primaryColor,
    String? accentColor,
    String? backgroundColor,
    String? surfaceColor,
    String? cardColor,
    String? textPrimaryColor,
    String? textSecondaryColor,
    String? dividerColor,
    bool? isBuiltIn,
  }) {
    return AppThemeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      isDark: isDark ?? this.isDark,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      cardColor: cardColor ?? this.cardColor,
      textPrimaryColor: textPrimaryColor ?? this.textPrimaryColor,
      textSecondaryColor: textSecondaryColor ?? this.textSecondaryColor,
      dividerColor: dividerColor ?? this.dividerColor,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'isDark': isDark,
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'backgroundColor': backgroundColor,
      'surfaceColor': surfaceColor,
      'cardColor': cardColor,
      'textPrimaryColor': textPrimaryColor,
      'textSecondaryColor': textSecondaryColor,
      'dividerColor': dividerColor,
      'isBuiltIn': isBuiltIn,
    };
  }

  factory AppThemeConfig.fromJson(Map<String, dynamic> json) {
    return AppThemeConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      isDark: json['isDark'] as bool? ?? true,
      primaryColor: json['primaryColor'] as String,
      accentColor: json['accentColor'] as String,
      backgroundColor: json['backgroundColor'] as String,
      surfaceColor: json['surfaceColor'] as String,
      cardColor: json['cardColor'] as String,
      textPrimaryColor: json['textPrimaryColor'] as String,
      textSecondaryColor: json['textSecondaryColor'] as String,
      dividerColor: json['dividerColor'] as String,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
    );
  }

  String toJsonString() => jsonEncode(toJson());

  factory AppThemeConfig.fromJsonString(String jsonString) {
    return AppThemeConfig.fromJson(
        jsonDecode(jsonString) as Map<String, dynamic>);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppThemeConfig && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Built-in themes
class BuiltInThemes {
  static const defaultDark = AppThemeConfig(
    id: 'default_dark',
    name: 'Default Dark',
    isDark: true,
    primaryColor: '#229AF0',
    accentColor: '#229AF0',
    backgroundColor: '#222931',
    surfaceColor: '#222931',
    cardColor: '#2A313D',
    textPrimaryColor: '#E9EDF3',
    textSecondaryColor: '#8A8A8E',
    dividerColor: '#37404D',
    isBuiltIn: true,
  );

  static const defaultLight = AppThemeConfig(
    id: 'default_light',
    name: 'Default Light',
    isDark: false,
    primaryColor: '#6366F1',
    accentColor: '#8B5CF6',
    backgroundColor: '#FFFFFF',
    surfaceColor: '#F5F5F5',
    cardColor: '#FFFFFF',
    textPrimaryColor: '#171717',
    textSecondaryColor: '#737373',
    dividerColor: '#E5E5E5',
    isBuiltIn: true,
  );

  static const midnight = AppThemeConfig(
    id: 'midnight',
    name: 'Midnight',
    isDark: true,
    primaryColor: '#3B82F6',
    accentColor: '#60A5FA',
    backgroundColor: '#0A0A1A',
    surfaceColor: '#111128',
    cardColor: '#1E1E3F',
    textPrimaryColor: '#E0E0FF',
    textSecondaryColor: '#8080B0',
    dividerColor: '#2A2A4A',
    isBuiltIn: true,
  );

  static const forest = AppThemeConfig(
    id: 'forest',
    name: 'Forest',
    isDark: true,
    primaryColor: '#22C55E',
    accentColor: '#4ADE80',
    backgroundColor: '#0A1A0A',
    surfaceColor: '#112811',
    cardColor: '#1E3F1E',
    textPrimaryColor: '#E0FFE0',
    textSecondaryColor: '#80B080',
    dividerColor: '#2A4A2A',
    isBuiltIn: true,
  );

  static const sunset = AppThemeConfig(
    id: 'sunset',
    name: 'Sunset',
    isDark: true,
    primaryColor: '#F97316',
    accentColor: '#FB923C',
    backgroundColor: '#1A0F0A',
    surfaceColor: '#281811',
    cardColor: '#3F2A1E',
    textPrimaryColor: '#FFE8E0',
    textSecondaryColor: '#B09080',
    dividerColor: '#4A3A2A',
    isBuiltIn: true,
  );

  static const rose = AppThemeConfig(
    id: 'rose',
    name: 'Rose',
    isDark: true,
    primaryColor: '#EC4899',
    accentColor: '#F472B6',
    backgroundColor: '#1A0A14',
    surfaceColor: '#281120',
    cardColor: '#3F1E32',
    textPrimaryColor: '#FFE0F0',
    textSecondaryColor: '#B08090',
    dividerColor: '#4A2A3A',
    isBuiltIn: true,
  );

  static const ocean = AppThemeConfig(
    id: 'ocean',
    name: 'Ocean',
    isDark: true,
    primaryColor: '#06B6D4',
    accentColor: '#22D3EE',
    backgroundColor: '#0A1418',
    surfaceColor: '#112028',
    cardColor: '#1E323F',
    textPrimaryColor: '#E0F8FF',
    textSecondaryColor: '#80A8B0',
    dividerColor: '#2A424A',
    isBuiltIn: true,
  );

  static const amoled = AppThemeConfig(
    id: 'amoled',
    name: 'AMOLED Black',
    isDark: true,
    primaryColor: '#8B5CF6',
    accentColor: '#A78BFA',
    backgroundColor: '#000000',
    surfaceColor: '#0A0A0A',
    cardColor: '#141414',
    textPrimaryColor: '#FFFFFF',
    textSecondaryColor: '#888888',
    dividerColor: '#222222',
    isBuiltIn: true,
  );

  // ============================================
  // LIGHT THEMES
  // ============================================

  /// Clean white theme with blue accents
  static const cleanWhite = AppThemeConfig(
    id: 'clean_white',
    name: 'Clean White',
    isDark: false,
    primaryColor: '#3B82F6',
    accentColor: '#60A5FA',
    backgroundColor: '#FFFFFF',
    surfaceColor: '#F8FAFC',
    cardColor: '#FFFFFF',
    textPrimaryColor: '#1E293B',
    textSecondaryColor: '#64748B',
    dividerColor: '#E2E8F0',
    isBuiltIn: true,
  );

  /// Warm cream theme
  static const warmCream = AppThemeConfig(
    id: 'warm_cream',
    name: 'Warm Cream',
    isDark: false,
    primaryColor: '#D97706',
    accentColor: '#F59E0B',
    backgroundColor: '#FFFBEB',
    surfaceColor: '#FEF3C7',
    cardColor: '#FFFFFF',
    textPrimaryColor: '#78350F',
    textSecondaryColor: '#92400E',
    dividerColor: '#FDE68A',
    isBuiltIn: true,
  );

  /// Soft lavender theme
  static const softLavender = AppThemeConfig(
    id: 'soft_lavender',
    name: 'Soft Lavender',
    isDark: false,
    primaryColor: '#8B5CF6',
    accentColor: '#A78BFA',
    backgroundColor: '#FAF5FF',
    surfaceColor: '#F3E8FF',
    cardColor: '#FFFFFF',
    textPrimaryColor: '#581C87',
    textSecondaryColor: '#7C3AED',
    dividerColor: '#E9D5FF',
    isBuiltIn: true,
  );

  /// Mint fresh theme
  static const mintFresh = AppThemeConfig(
    id: 'mint_fresh',
    name: 'Mint Fresh',
    isDark: false,
    primaryColor: '#10B981',
    accentColor: '#34D399',
    backgroundColor: '#ECFDF5',
    surfaceColor: '#D1FAE5',
    cardColor: '#FFFFFF',
    textPrimaryColor: '#064E3B',
    textSecondaryColor: '#047857',
    dividerColor: '#A7F3D0',
    isBuiltIn: true,
  );

  /// Sky blue theme
  static const skyBlue = AppThemeConfig(
    id: 'sky_blue',
    name: 'Sky Blue',
    isDark: false,
    primaryColor: '#0EA5E9',
    accentColor: '#38BDF8',
    backgroundColor: '#F0F9FF',
    surfaceColor: '#E0F2FE',
    cardColor: '#FFFFFF',
    textPrimaryColor: '#0C4A6E',
    textSecondaryColor: '#0369A1',
    dividerColor: '#BAE6FD',
    isBuiltIn: true,
  );

  /// Rose pink theme
  static const rosePink = AppThemeConfig(
    id: 'rose_pink',
    name: 'Rose Pink',
    isDark: false,
    primaryColor: '#EC4899',
    accentColor: '#F472B6',
    backgroundColor: '#FDF2F8',
    surfaceColor: '#FCE7F3',
    cardColor: '#FFFFFF',
    textPrimaryColor: '#831843',
    textSecondaryColor: '#BE185D',
    dividerColor: '#FBCFE8',
    isBuiltIn: true,
  );

  /// Peach theme
  static const peach = AppThemeConfig(
    id: 'peach',
    name: 'Peach',
    isDark: false,
    primaryColor: '#F97316',
    accentColor: '#FB923C',
    backgroundColor: '#FFF7ED',
    surfaceColor: '#FFEDD5',
    cardColor: '#FFFFFF',
    textPrimaryColor: '#7C2D12',
    textSecondaryColor: '#C2410C',
    dividerColor: '#FED7AA',
    isBuiltIn: true,
  );

  /// Sage green theme
  static const sageGreen = AppThemeConfig(
    id: 'sage_green',
    name: 'Sage Green',
    isDark: false,
    primaryColor: '#65A30D',
    accentColor: '#84CC16',
    backgroundColor: '#F7FEE7',
    surfaceColor: '#ECFCCB',
    cardColor: '#FFFFFF',
    textPrimaryColor: '#365314',
    textSecondaryColor: '#4D7C0F',
    dividerColor: '#D9F99D',
    isBuiltIn: true,
  );

  /// Paper theme (warm white like paper)
  static const paper = AppThemeConfig(
    id: 'paper',
    name: 'Paper',
    isDark: false,
    primaryColor: '#6366F1',
    accentColor: '#818CF8',
    backgroundColor: '#FAFAF9',
    surfaceColor: '#F5F5F4',
    cardColor: '#FFFFFF',
    textPrimaryColor: '#292524',
    textSecondaryColor: '#78716C',
    dividerColor: '#E7E5E4',
    isBuiltIn: true,
  );

  /// Sepia theme (book-like)
  static const sepia = AppThemeConfig(
    id: 'sepia',
    name: 'Sepia',
    isDark: false,
    primaryColor: '#A16207',
    accentColor: '#CA8A04',
    backgroundColor: '#FEF9E7',
    surfaceColor: '#FEF3C7',
    cardColor: '#FFFBEB',
    textPrimaryColor: '#713F12',
    textSecondaryColor: '#A16207',
    dividerColor: '#FDE68A',
    isBuiltIn: true,
  );

  static const List<AppThemeConfig> all = [
    // Dark themes
    defaultDark,
    midnight,
    forest,
    sunset,
    rose,
    ocean,
    amoled,
    // Light themes
    defaultLight,
    cleanWhite,
    warmCream,
    softLavender,
    mintFresh,
    skyBlue,
    rosePink,
    peach,
    sageGreen,
    paper,
    sepia,
  ];
}

/// Semantic Neko color tokens resolved from the active theme.
///
/// Widgets read these through `context.neko` (see [NekoContextX]) instead of
/// referencing the dark constants on `AppTheme`, so a single code path serves
/// every built-in and user-created theme. Registered as a [ThemeExtension] by
/// [AppThemeConfig.toThemeData].
@immutable
class NekoColors extends ThemeExtension<NekoColors> {
  /// Page background (content scrolls behind the floating nav pill).
  final Color background;

  /// Bar / panel surface that fuses with [background] — Neko app bars show no
  /// seam against the page.
  final Color surface;

  /// Grouped card / dialog / sheet / menu surface.
  final Color card;

  /// Subtle row separator inside a [card].
  final Color divider;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Outgoing (user) chat bubble.
  final Color userBubble;

  /// Incoming (assistant) chat bubble.
  final Color assistantBubble;

  /// Accent used for selection, links and the send action.
  final Color accent;

  /// Floating GlassTab pill (see `app_shell.dart`).
  final Color glassTabBackground;
  final Color glassTabBorder;
  final Color glassTabSelected;
  final Color glassTabUnselected;
  final Color glassTabSelectedText;

  const NekoColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.userBubble,
    required this.assistantBubble,
    required this.accent,
    required this.glassTabBackground,
    required this.glassTabBorder,
    required this.glassTabSelected,
    required this.glassTabUnselected,
    required this.glassTabSelectedText,
  });

  /// Used when a widget renders outside a themed subtree (route transitions,
  /// frames before `MaterialApp` mounts). Mirrors the dark Neko palette.
  static const NekoColors fallback = NekoColors(
    background: Color(0xFF222931),
    surface: Color(0xFF222931),
    card: Color(0xFF2A313D),
    divider: Color(0xFF37404D),
    textPrimary: Color(0xFFE9EDF3),
    textSecondary: Color(0xFF8A8A8E),
    textMuted: Color(0xFF5E6B7A),
    userBubble: Color(0xFF1F4E79),
    assistantBubble: Color(0xFF2A313D),
    accent: Color(0xFF229AF0),
    glassTabBackground: Color(0xE62A313D),
    glassTabBorder: Color(0xFF2E3A47),
    glassTabSelected: Color(0xFF229AF0),
    glassTabUnselected: Color(0xFF8A8A8E),
    glassTabSelectedText: Color(0xFFFFFFFF),
  );

  /// Derive the token set from a theme config.
  factory NekoColors.fromConfig(AppThemeConfig cfg) {
    final bool dark = cfg.isDark;
    return NekoColors(
      background: cfg.background,
      surface: cfg.surface,
      card: cfg.card,
      divider: cfg.divider,
      textPrimary: cfg.textPrimary,
      textSecondary: cfg.textSecondary,
      // The config has no muted slot: fade secondary text toward the page
      // background (30% on dark, 10% on light so it stays legible).
      textMuted: Color.lerp(
        cfg.textSecondary,
        cfg.background,
        dark ? 0.30 : 0.10,
      )!,
      // Dark keeps the hand-picked Neko navy; light derives a soft blue tint.
      userBubble: dark
          ? const Color(0xFF1F4E79)
          : Color.alphaBlend(cfg.primary.withValues(alpha: 0.14), cfg.card),
      assistantBubble: cfg.card,
      accent: cfg.accent,
      glassTabBackground: cfg.card.withValues(alpha: 0.90),
      glassTabBorder: cfg.divider,
      glassTabSelected: cfg.accent,
      glassTabUnselected: cfg.textSecondary,
      // A white label only reads on the dark pill; light themes use the accent.
      glassTabSelectedText: dark ? Colors.white : cfg.accent,
    );
  }

  /// Tokens for [context], falling back to the dark Neko palette.
  static NekoColors of(BuildContext context) =>
      Theme.of(context).extension<NekoColors>() ?? fallback;

  @override
  NekoColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? userBubble,
    Color? assistantBubble,
    Color? accent,
    Color? glassTabBackground,
    Color? glassTabBorder,
    Color? glassTabSelected,
    Color? glassTabUnselected,
    Color? glassTabSelectedText,
  }) {
    return NekoColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      userBubble: userBubble ?? this.userBubble,
      assistantBubble: assistantBubble ?? this.assistantBubble,
      accent: accent ?? this.accent,
      glassTabBackground: glassTabBackground ?? this.glassTabBackground,
      glassTabBorder: glassTabBorder ?? this.glassTabBorder,
      glassTabSelected: glassTabSelected ?? this.glassTabSelected,
      glassTabUnselected: glassTabUnselected ?? this.glassTabUnselected,
      glassTabSelectedText:
          glassTabSelectedText ?? this.glassTabSelectedText,
    );
  }

  @override
  NekoColors lerp(covariant NekoColors? other, double t) {
    if (other == null) return this;
    return NekoColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      assistantBubble: Color.lerp(assistantBubble, other.assistantBubble, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      glassTabBackground:
          Color.lerp(glassTabBackground, other.glassTabBackground, t)!,
      glassTabBorder: Color.lerp(glassTabBorder, other.glassTabBorder, t)!,
      glassTabSelected: Color.lerp(glassTabSelected, other.glassTabSelected, t)!,
      glassTabUnselected:
          Color.lerp(glassTabUnselected, other.glassTabUnselected, t)!,
      glassTabSelectedText:
          Color.lerp(glassTabSelectedText, other.glassTabSelectedText, t)!,
    );
  }
}

/// `context.neko` — semantic Neko tokens for the active theme.
extension NekoContextX on BuildContext {
  NekoColors get neko => NekoColors.of(this);
}
