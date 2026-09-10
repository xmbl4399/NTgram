import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';

/// Keeps overflow actions anchored to their trigger on every platform.
///
/// Flutter 3.44.9 or newer is required because older releases could interpret
/// an iPadOS top-bar tap twice and immediately dismiss the opened menu.
///
/// The popup is themed to Nekogram's compact overflow menu: a rounded card
/// surface (`#2A313D`) with tight, single-height rows and a soft shadow.
class AdaptivePopupMenuButton<T> extends StatelessWidget {
  const AdaptivePopupMenuButton({
    super.key,
    required this.itemBuilder,
    required this.onSelected,
    this.icon,
    this.tooltip,
    this.padding = const EdgeInsets.all(8),
    this.iconSize,
    this.constraints,
    this.enabled = true,
    this.menuRadius = 14,
  });

  final PopupMenuItemBuilder<T> itemBuilder;
  final PopupMenuItemSelected<T> onSelected;
  final Widget? icon;
  final String? tooltip;
  final EdgeInsetsGeometry padding;
  final double? iconSize;
  final BoxConstraints? constraints;
  final bool enabled;
  final double menuRadius;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      itemBuilder: itemBuilder,
      onSelected: onSelected,
      icon: icon,
      tooltip: tooltip,
      padding: padding,
      iconSize: iconSize,
      constraints: constraints,
      enabled: enabled,
      color: context.neko.card,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(menuRadius),
      ),
      menuPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      position: PopupMenuPosition.under,
    );
  }
}
