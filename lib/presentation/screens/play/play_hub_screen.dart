import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/play/ai_play_feature_gate.dart';

/// Play tab hub: four names only. No timeline, switches, or status.
class PlayHubScreen extends ConsumerWidget {
  const PlayHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.playHub)),
      // Neko-style rounded card wrapping the hub rows, height follows content.
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 24),
        child: Material(
          color: context.neko.card,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _PlayHubRow(
                key: const Key('play-hub-moments'),
                icon: Icons.dynamic_feed_outlined,
                iconColor: const Color(0xFFF472B6), // pink
                title: l10n.moments,
                onTap: () async {
                  final enabled = await ensureAiPlayFeatureEnabled(
                    context,
                    ref,
                    AiPlayFeature.moments,
                  );
                  if (enabled && context.mounted) {
                    context.push(AppRoutes.playMoments);
                  }
                },
              ),
              _PlayHubRow(
                key: const Key('play-hub-story'),
                icon: Icons.menu_book_outlined,
                iconColor: const Color(0xFFF59E0B), // amber
                title: l10n.story,
                onTap: () async {
                  final enabled = await ensureAiPlayFeatureEnabled(
                    context,
                    ref,
                    AiPlayFeature.story,
                  );
                  if (enabled && context.mounted) {
                    context.push(AppRoutes.playStory);
                  }
                },
              ),
              _PlayHubRow(
                key: const Key('play-hub-world-info'),
                icon: Icons.public_outlined,
                iconColor: const Color(0xFF22D3EE), // cyan
                title: l10n.worldInfo,
                onTap: () => context.push(AppRoutes.worldInfo),
              ),
              _PlayHubRow(
                key: const Key('play-hub-data-bank'),
                icon: Icons.library_books_outlined,
                iconColor: const Color(0xFF818CF8), // indigo
                title: l10n.dataBank,
                onTap: () => context.push(AppRoutes.dataBank),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayHubRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  const _PlayHubRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 0,
      minTileHeight: AppTheme.navPageRowHeight,
      leading: Icon(icon, size: 24, color: iconColor),
      title: Text(
        title,
        style: TextStyle(
          color: context.neko.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: AppTheme.textMuted,
      ),
      onTap: onTap,
    );
  }
}
