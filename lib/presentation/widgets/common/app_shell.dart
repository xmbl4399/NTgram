import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';

/// Main app shell with a Neko-style floating GlassTab bottom bar.
///
/// Unlike a pinned Material `bottomNavigationBar`, the bar is rendered as a
/// centered 328dp frosted pill floating over the body (same as Neko's
/// `MainTabsActivity`): everything outside the pill stays transparent so the
/// underlying list scrolls through, and a 60dp fade gradient eases the list
/// into the bottom edge.
class AppShell extends StatefulWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with RouteAware {
  bool _navVisible = true;
  double _lastOffset = 0;
  /// When a route is pushed over the shell (e.g. a settings submenu,
  /// character detail) the pill hides too. Raw modal bottom sheets do not
  /// route through GoRouter, so screens opt in by toggling
  /// [bottomSheetNavSignal] around the sheet call.
  bool _overlayVisible = true;

  bool get _pillVisible => _navVisible && _overlayVisible;

  @override
  void initState() {
    super.initState();
    bottomSheetNavSignal.addListener(_onSheetSignalChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    bottomSheetNavSignal.removeListener(_onSheetSignalChanged);
    super.dispose();
  }

  void _onSheetSignalChanged() {
    final shouldHide = bottomSheetNavSignal.value;
    if (shouldHide == !_overlayVisible) return;
    setState(() => _overlayVisible = !shouldHide);
  }

  /// A route/modal was pushed above the shell page — cover the nav pill.
  @override
  void didPushNext() {
    if (_overlayVisible) setState(() => _overlayVisible = false);
  }

  /// The covering route/modal was popped — bring the pill back.
  @override
  void didPopNext() {
    if (!_overlayVisible) setState(() => _overlayVisible = true);
  }

  /// Auto-hide the floating nav pill while the content scrolls down, and
  /// bring it back when scrolling up (near Neko's floating-toolbar gesture).
  /// Prevents the pill from permanently covering bottom rows on long lists.
  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final offset = notification.metrics.pixels;
      // Only toggle when actually scrolling (delta, not momentum).
      final delta = offset - _lastOffset;
      _lastOffset = offset;
      final atTop = offset <= 4;

      // Neko-like auto-hide: the pill stays hidden while scrolling down or
      // resting at the bottom of a long list; it reappears only when the user
      // scrolls up or returns to the top.
      bool shouldShow = _navVisible;
      if (delta < -2 || atTop) {
        shouldShow = true;
      } else if (delta > 2) {
        shouldShow = false;
      }
      if (shouldShow != _navVisible) {
        setState(() => _navVisible = shouldShow);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            const _BottomFade(),
            // Auto-hiding floating pill: Positioned stays a direct Stack
            // child; the slide/fade animate the pill content itself.
            Positioned(
              left: _GlassNavPill._margin,
              right: _GlassNavPill._margin,
              bottom: _GlassNavPill._margin,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                offset: _pillVisible ? Offset.zero : const Offset(0, 1.8),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _pillVisible ? 1 : 0,
                  child: const _GlassNavPill(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom fade gradient (corresponds to Neko's `BlurredBackgroundWithFadeDrawable`
/// fade height of 60dp): the list darkens into the bottom edge so content
/// scrolls under the pill instead of cutting off sharply.
class _BottomFade extends StatelessWidget {
  const _BottomFade();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 60,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                AppTheme.darkBackground.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The centered frosted pill bar.
class _GlassNavPill extends StatelessWidget {
  const _GlassNavPill();

  static const double _height = 56;
  static const double _radius = 28;
  static const double _margin = 8;
  static const double _maxWidth = 328; // Neko MAIN_TABS 328dp

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    final l10n = AppLocalizations.of(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.glassTabBackground,
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(color: AppTheme.glassTabBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.20),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_radius - 4),
          child: Row(
            children: [
              _PillTab(
                selected: selectedIndex == 0,
                icon: Icons.chat_bubble_outline,
                iconSel: Icons.chat_bubble,
                label: l10n.chats,
                onTap: () => _onItemTapped(context, 0),
              ),
              _PillTab(
                selected: selectedIndex == 1,
                icon: Icons.people_outline,
                iconSel: Icons.people,
                label: l10n.characters,
                onTap: () => _onItemTapped(context, 1),
              ),
              _PillTab(
                selected: selectedIndex == 2,
                icon: Icons.explore_outlined,
                iconSel: Icons.explore,
                label: l10n.playHub,
                onTap: () => _onItemTapped(context, 2),
              ),
              _PillTab(
                selected: selectedIndex == 3,
                icon: Icons.auto_awesome_outlined,
                iconSel: Icons.auto_awesome,
                label: l10n.aiConfig,
                onTap: () => _onItemTapped(context, 3),
              ),
              _PillTab(
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

/// One tab cell inside the pill.
///
/// Neko draws its selected capsule inside each `GlassTabView` (accent at 9%
/// alpha, full-rounded), scaling from 60% while leaving unselected tabs fully
/// transparent apart from icon + label.
class _PillTab extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final IconData iconSel;
  final String label;
  final VoidCallback onTap;

  const _PillTab({
    required this.selected,
    required this.icon,
    required this.iconSel,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedScale(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOutCubic,
        scale: selected ? 1.0 : 0.92,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.glassTabSelected.withValues(
                    alpha: AppTheme.glassTabSelectedAlpha,
                  )
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
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
}
