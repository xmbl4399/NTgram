import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';

/// Log a message to the console with SnackBar context
void _logSnackBar(String message, {String? error, StackTrace? stackTrace}) {
  final timestamp = DateTime.now().toIso8601String();
  final logMessage = '[$timestamp] SnackBar: $message';

  if (kDebugMode) {
    debugPrint(logMessage);
    if (error != null) {
      debugPrint('  Error: $error');
    }
  }

  developer.log(
    message,
    name: 'SnackBar',
    error: error,
    stackTrace: stackTrace,
  );
}

/// Build a Neko-style floating toast.
///
/// Shape, floating behaviour, elevation and the default surface all come from
/// `snackBarTheme` (see `AppThemeConfig.toThemeData`); this only adds the
/// optional leading icon and keeps the message legible when a caller supplies
/// a custom background.
SnackBar _nekoSnackBar(
  BuildContext context,
  String message, {
  required Duration duration,
  SnackBarAction? action,
  Color? backgroundColor,
  IconData? icon,
}) {
  final Color foreground = backgroundColor == null
      ? context.neko.textPrimary
      : (ThemeData.estimateBrightnessForColor(backgroundColor) ==
              Brightness.dark
          ? Colors.white
          : Colors.black87);

  return SnackBar(
    duration: duration,
    action: action,
    backgroundColor: backgroundColor,
    content: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(message, style: TextStyle(color: foreground, fontSize: 13)),
        ),
      ],
    ),
  );
}

/// Show a SnackBar with automatic logging
///
/// This utility function wraps ScaffoldMessenger.showSnackBar with logging
/// to help debug UI messages in production.
void showLoggedSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
  Color? backgroundColor,
  bool isError = false,
}) {
  _logSnackBar(message, error: isError ? message : null);

  ScaffoldMessenger.of(context).showSnackBar(
    _nekoSnackBar(
      context,
      message,
      duration: duration,
      action: action,
      backgroundColor: backgroundColor ?? (isError ? Colors.red.shade700 : null),
      icon: isError ? Icons.error_outline : null,
    ),
  );
}

/// Show an error SnackBar with automatic logging
void showErrorSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 4),
  SnackBarAction? action,
  Object? error,
  StackTrace? stackTrace,
}) {
  _logSnackBar(message, error: error?.toString(), stackTrace: stackTrace);

  ScaffoldMessenger.of(context).showSnackBar(
    _nekoSnackBar(
      context,
      message,
      duration: duration,
      action: action,
      backgroundColor: Colors.red.shade700,
      icon: Icons.error_outline,
    ),
  );
}

/// Show a success SnackBar with automatic logging
void showSuccessSnackBar(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
}) {
  _logSnackBar(message);

  ScaffoldMessenger.of(context).showSnackBar(
    _nekoSnackBar(
      context,
      message,
      duration: duration,
      action: action,
      backgroundColor: Colors.green.shade700,
      icon: Icons.check_circle_outline,
    ),
  );
}

/// Extension on ScaffoldMessengerState to add logging
extension LoggedSnackBarExtension on ScaffoldMessengerState {
  /// Show a SnackBar with automatic logging
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoggedSnackBar(
    SnackBar snackBar, {
    String? logMessage,
  }) {
    final message = logMessage ??
        (snackBar.content is Text ? (snackBar.content as Text).data : 'SnackBar shown');
    _logSnackBar(message ?? 'SnackBar shown');
    return showSnackBar(snackBar);
  }
}
