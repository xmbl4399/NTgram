import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';

/// Main app shell with a Neko-style floating GlassTab bottom bar.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: const _GlassNavBar(),
    );
  }
}

/// Neko "GlassTabView" floating pill bar.
///
/// Mirrors the Telegram/Neko `MainTabsLayout` visual: 56dp tall, 28dp radius,
/// centered translucent panel + border, vertical icon-over-label tabs. Each
/// tab draws its own selected capsule (accent at 9% alpha, full-rounded) so
/// there is no layout coupling to a fixed row width.
class _GlassNavBar extends StatefulWidget {
  const _GlassNavBar();

  static const double _tabHeight = 56;
  static const double _radius = 28;

  @override
  State<_GlassNavBar> createState() => _GlassNavBarState();
}

class _GlassNavBarState extends State<_GlassNavBar> {
  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final l10n = AppLocalizations.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          height: _GlassNavBar._tabHeight,
          decoration: BoxDecoration(
            color: AppTheme.glassTabBackground,
            borderRadius: BorderRadius.circular(_GlassNavBar._radius),
            border: Border.all(color: AppTheme.glassTabBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildTab(
                selected: selectedIndex == 0,
                icon: Icons.chat_bubble_outline,
                iconSel: Icons.chat_bubble,
                label: l10n.chats,
                onTap: () => _onItemTapped(context, 0),
              ),
              _buildTab(
                selected: selectedIndex == 1,
                icon: Icons.people_outline,
                iconSel: Icons.people,
                label: l10n.characters,
                onTap: () => _onItemTapped(context, 1),
              ),
              _buildTab(
                selected: selectedIndex == 2,
                icon: Icons.explore_outlined,
                iconSel: Icons.explore,
                label: l10n.playHub,
                onTap: () => _onItemTapped(context, 2),
              ),
              _buildTab(
                selected: selectedIndex == 3,
                icon: Icons.auto_awesome_outlined,
                iconSel: Icons.auto_awesome,
                label: l10n.aiConfig,
                onTap: () => _onItemTapped(context, 3),
              ),
              _buildTab(
                selected: selectedIndex == 4,
                icon: Icons.settings_outlined,
                iconSel: Icons.settings,
                label: l10n.settings,
                onTap: () => _onItemTapped(context, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab({
    required bool selected,
    required IconData icon,
    required IconData iconSel,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.glassTabSelected.withValues(
                    alpha: AppTheme.glassTabSelectedAlpha,
                  )
                : Colors.transparent,
            borderRadius:
                BorderRadius.circular(_GlassNavBar._radius - 6),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_GlassNavBar._radius - 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? iconSel : icon,
                  size: 23,
                  color: selected
                      ? AppTheme.glassTabSelected
                      : AppTheme.glassTabUnselected,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppTheme.glassTabSelectedText
                        : AppTheme.glassTabUnselected,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/characters')) return 1;
    if (location.startsWith('/play') || location.startsWith('/world-info')) {
      return 2;
    }
    if (location.startsWith('/ai-config')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.home);
        break;
      case 1:
        context.go(AppRoutes.characters);
        break;
      case 2:
        context.go(AppRoutes.play);
        break;
      case 3:
        context.go(AppRoutes.aiConfig);
        break;
      case 4:
        context.go(AppRoutes.settings);
        break;
    }
  }
}