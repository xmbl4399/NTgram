import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';

/// Visual flavour of an [AppToast].
enum AppToastKind {
  /// Plain information — "聊天已删除", "已复制到剪贴板".
  neutral,

  /// Confirmation of a completed action.
  success,

  /// Failure / error report.
  error,
}

/// Overlay based, self-dismissing toast used for every fire-and-forget
/// confirmation in the app.
///
/// Why this replaces `ScaffoldMessenger.showSnackBar` for notifications:
///
///  * A [SnackBar] lives inside the `Scaffold` layout. On the chat screen the
///    bottom slot sits under the composer, so a one-line confirmation either
///    fights the input bar or jumps around while the keyboard animates.
///  * Material's SnackBar falls back to a **4 second** display. Most of these
///    are one-liners, and four seconds of banner is exactly what made
///    "聊天已删除" feel intrusive.
///  * SnackBars are hit-testable. A toast must never steal a tap from the
///    message list underneath it.
///
/// So the toast renders into the root [Overlay] instead: horizontally centred
/// and parked just above the app's bottom bar (the floating nav pill, or the
/// chat composer), lifted above the soft keyboard when one is open, fading in
/// and out on its own after [defaultDuration].
///
/// Interactive prompts that need a button (undo, "open system settings") stay
/// real [SnackBar]s — a toast cannot be tapped.
class AppToast {
  AppToast._();

  /// How long a toast stays fully visible before it starts fading out.
  static const Duration defaultDuration = Duration(milliseconds: 1800);

  /// Length of the fade-in / fade-out transition.
  static const Duration fadeDuration = Duration(milliseconds: 160);

  /// Clearance kept free at the bottom, so the toast floats just above the
  /// bottom bar instead of sitting on top of it. The floating nav pill is
  /// 8 dp margin + 56 dp tall + 8 dp breathing room (see `app_shell.dart`),
  /// and the chat composer is of a similar height; 78 dp clears both.
  static const double _bottomBarClearance = 78;

  static const double _minWidth = 110;
  static const double _maxWidth = 320;

  /// Fallback overlay lookup for widgets that live *above* the [Navigator] —
  /// notably anything built inside `MaterialApp.builder`, where no [Overlay]
  /// is reachable from `context`. `NativeTavernApp` points this at the root
  /// navigator's overlay.
  static OverlayState? Function()? rootOverlayResolver;

  static OverlayEntry? _entry;

  /// Shows [message] in the root overlay of [context]'s tree.
  static void show(
    BuildContext context,
    String message, {
    AppToastKind kind = AppToastKind.neutral,
    Duration duration = defaultDuration,
  }) => showIn(
    Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context),
    message,
    kind: kind,
    duration: duration,
  );

  /// Same as [show], for callers that resolved the overlay *before* an `await`
  /// (keeps a [BuildContext] from being held across an async gap).
  ///
  /// A null [overlay] (no [Overlay] reachable from the call site) falls back to
  /// [rootOverlayResolver] and, failing that, drops the toast after logging it.
  static void showIn(
    OverlayState? overlay,
    String message, {
    AppToastKind kind = AppToastKind.neutral,
    Duration duration = defaultDuration,
  }) {
    final text = message.trim();
    if (text.isEmpty) return;

    developer.log(text, name: 'AppToast');

    final target = overlay ?? rootOverlayResolver?.call();
    if (target == null) {
      // No overlay yet (app boot / detached subtree) — the message is still
      // in the debug log above, so dropped feedback stays traceable.
      return;
    }

    // Single toast at a time: a newer message replaces the one on screen.
    dismiss();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppToastView(
        message: text,
        kind: kind,
        duration: duration,
        onFinished: () {
          if (identical(_entry, entry)) _entry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    target.insert(entry);
  }

  /// Shorthand for [AppToastKind.success].
  static void success(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
  }) => show(context, message, kind: AppToastKind.success, duration: duration);

  /// Shorthand for [AppToastKind.error].
  static void error(
    BuildContext context,
    String message, {
    Duration duration = defaultDuration,
  }) => show(context, message, kind: AppToastKind.error, duration: duration);

  /// Removes the toast currently on screen, if any.
  static void dismiss() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _AppToastView extends StatefulWidget {
  const _AppToastView({
    required this.message,
    required this.kind,
    required this.duration,
    required this.onFinished,
  });

  final String message;
  final AppToastKind kind;
  final Duration duration;
  final VoidCallback onFinished;

  @override
  State<_AppToastView> createState() => _AppToastViewState();
}

class _AppToastViewState extends State<_AppToastView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppToast.fadeDuration,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // Above the keyboard when it is open (the composer rides on its top edge),
    // otherwise just above the bottom bar / system navigation area.
    final bottom =
        (keyboard > 0 ? keyboard : safeBottom) + AppToast._bottomBarClearance;
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.22),
              end: Offset.zero,
            ).animate(curved),
            child: Center(
              child: Semantics(
                liveRegion: true,
                container: true,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: AppToast._minWidth,
                    maxWidth: math.min(AppToast._maxWidth, size.width - 72),
                  ),
                  child: _buildBubble(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBubble(BuildContext context) {
    final neko = context.neko;
    final Color background;
    final Color foreground;
    final Color border;
    IconData? icon;

    switch (widget.kind) {
      case AppToastKind.neutral:
        background = neko.card;
        foreground = neko.textPrimary;
        border = neko.divider;
      case AppToastKind.success:
        background = const Color(0xFF2E7D32);
        foreground = Colors.white;
        border = Colors.white24;
        icon = Icons.check_circle_outline;
      case AppToastKind.error:
        background = const Color(0xFFC62828);
        foreground = Colors.white;
        border = Colors.white24;
        icon = Icons.error_outline;
    }

    // `Material` (transparent) is not decoration — it re-establishes a sane
    // `DefaultTextStyle`. An Overlay entry sits *outside* any `Scaffold`, so
    // without it the text inherits `MaterialApp`'s fallback style, whose
    // `TextDecorationStyle.double` + yellow `decorationColor` leak through as a
    // double underline under every toast.
    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.30),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            // `_minWidth` can widen the capsule past the text; centre so the
            // leftover space is split evenly instead of piling up on the right.
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, size: 16, color: foreground),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 13,
                    height: 1.35,
                  ),
                  textAlign: icon == null ? TextAlign.center : TextAlign.start,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
