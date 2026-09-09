import 'dart:async';
import 'package:flutter/material.dart';

/// In-app launch overlay (Nekogram style): flat #0E1621 fill with the full
/// uncropped app logo centered, fading out once the app is interactive.
///
/// The OS-level splash (Android 12+ SplashScreen API) intentionally renders
/// only a flat color — an animated icon there would crop the full-bleed
/// launcher image to the OS safe zone. This overlay draws the logo on the
/// first Flutter frame with the same background color, so the two phases
/// look seamless and the logo is never cropped.
class AppSplashGate extends StatefulWidget {
  const AppSplashGate({super.key, required this.child});

  final Widget child;

  /// Minimum time the logo stays visible (fade-out cannot start before this),
  /// so the splash never flickers even when the first frame is very fast.
  static const Duration minHoldDuration = Duration(milliseconds: 400);

  @override
  State<AppSplashGate> createState() => _AppSplashGateState();
}

class _AppSplashGateState extends State<AppSplashGate> {
  bool _visible = true;
  bool _firstFrame = false;
  Timer? _minHoldTimer;

  @override
  void initState() {
    super.initState();
    // Leave as soon as both conditions hold: the first Flutter frame has been
    // drawn AND the minimum brand-hold time has elapsed. This removes the old
    // fixed 1s gate while still avoiding a splash that disappears too fast.
    _minHoldTimer = Timer(AppSplashGate.minHoldDuration, _maybeFadeOut);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _firstFrame = true;
      _maybeFadeOut();
    });
  }

  void _maybeFadeOut() {
    if (!_firstFrame) return;
    if (_minHoldTimer?.isActive ?? true) return;
    _minHoldTimer?.cancel();
    if (mounted && _visible) {
      setState(() => _visible = false);
    }
  }

  @override
  void dispose() {
    _minHoldTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: const ColoredBox(
              color: Color(0xFF0E1621),
              child: Center(
                child: Image(
                  image: AssetImage('assets/splash_logo.png'),
                  width: 128,
                  height: 128,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
