import 'package:flutter/material.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';

/// Neko settings card: a 16dp-radius surface painted with the theme's card
/// colour, hosting 60dp rows with **no** dividers between them.
///
/// This geometry used to be re-declared inline on every settings-style page —
/// two of the copies were byte-for-byte identical, and the rest drifted (some
/// cards had dividers, some were 48dp tall). Importing this instead keeps every
/// page on one set of numbers.
///
/// Rows go straight in; the card supplies the [ListTileTheme] they rely on, so
/// a bare `ListTile` needs no per-site `minTileHeight` / `minVerticalPadding`:
///
/// ```dart
/// NekoCard(
///   children: [
///     ListTile(leading: Icon(Icons.palette), title: Text('外观'), onTap: ...),
///     ListTile(leading: Icon(Icons.tune), title: Text('高级'), onTap: ...),
///   ],
/// )
/// ```
class NekoCard extends StatelessWidget {
  const NekoCard({
    super.key,
    required this.children,
    this.iconColor,
    this.margin = defaultMargin,
  });

  /// Rows stacked inside the card.
  final List<Widget> children;

  /// Overrides the leading icon colour of every row in the card.
  final Color? iconColor;

  /// Outer spacing; Neko cards sit slightly inset from the screen edge.
  final EdgeInsetsGeometry margin;

  /// Default inset of a Neko card inside a page.
  static const EdgeInsetsGeometry defaultMargin = EdgeInsets.symmetric(
    horizontal: 6,
  );

  /// Corner radius shared by every Neko card-like surface.
  static const double radius = 16;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: context.neko.card,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: ListTileTheme(
          data: ListTileThemeData(
            // 60dp rows with NO grey dividers between rows inside a card.
            minTileHeight: AppTheme.navPageRowHeight,
            minVerticalPadding: 0,
            iconColor: iconColor,
          ),
          child: Column(children: children),
        ),
      ),
    );
  }
}
