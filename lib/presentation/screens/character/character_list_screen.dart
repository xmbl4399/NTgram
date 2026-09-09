import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/character_providers.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';
import 'character_view_mode.dart';

/// Menu actions available on long-press of a character row.
enum _CharacterMenuItem { chat, edit, export, delete }

/// Character list screen
class CharacterListScreen extends ConsumerStatefulWidget {
  const CharacterListScreen({super.key});

  @override
  ConsumerState<CharacterListScreen> createState() =>
      _CharacterListScreenState();
}

class _CharacterListScreenState extends ConsumerState<CharacterListScreen> {
  String _searchQuery = '';
  bool _searchOpen = false;
  CharacterViewMode _viewMode = CharacterViewMode.list;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final charactersAsync = ref.watch(characterListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.characters),
        actions: [
          // Search toggle: taps drop a top-floating search field.
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.searchCharacters,
            onPressed: () => setState(() {
              _searchOpen = !_searchOpen;
            }),
          ),
          IconButton(
            icon: _getViewModeIcon(),
            onPressed: () => setState(() => _viewMode = _viewMode.next),
            tooltip: _viewMode.getDisplayName(l10n),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.createCharacter,
            onPressed: () => context.push(AppRoutes.characterCreate),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.retry,
            onPressed: () => ref.read(characterListProvider.notifier).refresh(),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l10n.import,
            onPressed: () => context.push(AppRoutes.import_),
          ),
        ],
      ),
      body: Column(
        children: [
          // Top-floating search field, revealed by the search button.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _searchOpen
                ? _SearchBar(
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _searchDebounce?.cancel();
                      _searchDebounce =
                          Timer(const Duration(milliseconds: 250), () {
                        if (mounted) {
                          ref
                              .read(characterListProvider.notifier)
                              .setQuery(value);
                        }
                      });
                    },
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.extentAfter < 600) {
                  ref.read(characterListProvider.notifier).loadMore();
                }
                return false;
              },
              child: charactersAsync.when(
                data: (characters) {
                  final filtered = _searchQuery.isEmpty
                      ? characters
                      : characters
                          .where((c) =>
                              c.name
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()) ||
                              c.description
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()))
                          .toList();

                  if (filtered.isEmpty) {
                    return const _EmptyState();
                  }

                  switch (_viewMode) {
                    case CharacterViewMode.list:
                      return _CharacterListView(characters: filtered);
                    case CharacterViewMode.grid:
                      return _CharacterGridView(characters: filtered);
                    case CharacterViewMode.compactGrid:
                      return _CharacterCompactGridView(characters: filtered);
                  }
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('${l10n.error}: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            ref.read(characterListProvider.notifier).refresh(),
                        child: Text(l10n.retry),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Icon _getViewModeIcon() {
    switch (_viewMode) {
      case CharacterViewMode.list:
        return const Icon(Icons.list);
      case CharacterViewMode.grid:
        return const Icon(Icons.grid_view);
      case CharacterViewMode.compactGrid:
        return const Icon(Icons.view_compact);
    }
  }
}

class _SearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: l10n.searchCharacters,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // TODO: Show filter options
            },
          ),
        ),
      ),
    );
  }
}

class _CharacterGridView extends StatelessWidget {
  final List<Character> characters;

  const _CharacterGridView({required this.characters});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        return _CharacterGridCard(character: characters[index]);
      },
    );
  }
}

class _CharacterListView extends ConsumerStatefulWidget {
  final List<Character> characters;

  const _CharacterListView({required this.characters});

  @override
  ConsumerState<_CharacterListView> createState() => _CharacterListViewState();
}

class _CharacterListViewState extends ConsumerState<_CharacterListView> {
  /// Swiped-away character ids, so the Dismissible leaves the tree before the
  /// async repo delete finishes.
  final Set<String> _dismissedIds = {};

  @override
  Widget build(BuildContext context) {
    final visible =
        widget.characters.where((c) => !_dismissedIds.contains(c.id));
    // Neko-style rounded card wrapping only the visible characters.
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 12),
      child: Material(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (final character in visible)
              _CharacterListTile(
                character: character,
                onDismissed: () => _dismissCharacter(character.id),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _dismissCharacter(String id) async {
    setState(() => _dismissedIds.add(id));
    final l10n = AppLocalizations.of(context);
    await ref.read(characterListProvider.notifier).deleteCharacter(id);
    if (mounted && _dismissedIds.contains(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.characterDeleted),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}

class _CharacterCompactGridView extends StatelessWidget {
  final List<Character> characters;

  const _CharacterCompactGridView({required this.characters});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.65,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: characters.length,
      itemBuilder: (context, index) {
        return _CharacterCompactGridCard(character: characters[index]);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: AppTheme.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noCharactersYet,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.importCharacter,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => context.push(AppRoutes.characterCreate),
                icon: const Icon(Icons.add),
                label: Text(l10n.createCharacter),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.import_),
                icon: const Icon(Icons.file_download),
                label: Text(l10n.import),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CharacterGridCard extends ConsumerWidget {
  final Character character;

  const _CharacterGridCard({required this.character});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/characters/${character.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _buildAvatar(),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      character.name,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (character.creator.isNotEmpty)
                      Text(
                        'by ${character.creator}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textMuted,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (character.assets?.avatarPath != null) {
      return CharacterAvatarImage(
        imagePath: character.assets!.avatarPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultAvatar(),
      );
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    final icon = _getCharacterIcon(character);
    final color = _getCharacterColor(character);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 60,
          color: Colors.white,
        ),
      ),
    );
  }

  IconData _getCharacterIcon(Character character) {
    // Check if it's a built-in character by ID
    switch (character.id) {
      case 'builtin_coding_assistant':
        return Icons.code;
      case 'builtin_image_gen_assistant':
        return Icons.image;
      case 'builtin_xiaohongshu_copywriter':
        return Icons.edit_note;
      default:
        return Icons.person;
    }
  }

  Color _getCharacterColor(Character character) {
    // Check if it's a built-in character by ID
    switch (character.id) {
      case 'builtin_coding_assistant':
        return const Color(0xFF2196F3); // Blue for coding
      case 'builtin_image_gen_assistant':
        return const Color(0xFFE91E63); // Pink for image generation
      case 'builtin_xiaohongshu_copywriter':
        return const Color(0xFFFF5722); // Orange/Red for social media
      default:
        return AppTheme.darkDivider;
    }
  }
}

class _CharacterCompactGridCard extends ConsumerWidget {
  final Character character;

  const _CharacterCompactGridCard({required this.character});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/characters/${character.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: _buildCompactAvatar(),
            ),
            Expanded(
              flex: 1,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      character.name,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactAvatar() {
    if (character.assets?.avatarPath != null) {
      return CharacterAvatarImage(
        imagePath: character.assets!.avatarPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _defaultCompactAvatar(),
      );
    }
    return _defaultCompactAvatar();
  }

  Widget _defaultCompactAvatar() {
    final icon = _getCharacterIcon(character);
    final color = _getCharacterColor(character);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  IconData _getCharacterIcon(Character character) {
    switch (character.id) {
      case 'builtin_coding_assistant':
        return Icons.code;
      case 'builtin_image_gen_assistant':
        return Icons.image;
      case 'builtin_xiaohongshu_copywriter':
        return Icons.edit_note;
      default:
        return Icons.person;
    }
  }

  Color _getCharacterColor(Character character) {
    switch (character.id) {
      case 'builtin_coding_assistant':
        return const Color(0xFF2196F3);
      case 'builtin_image_gen_assistant':
        return const Color(0xFFE91E63);
      case 'builtin_xiaohongshu_copywriter':
        return const Color(0xFFFF5722);
      default:
        return AppTheme.darkDivider;
    }
  }
}

class _CharacterListTile extends ConsumerWidget {
  final Character character;
  final VoidCallback onDismissed;

  const _CharacterListTile({
    required this.character,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Neko-style compact user row (UserCell/TextSettingsCell): 40dp avatar,
    // bold name, grey description, dense single row at Neko settings height.
    return Dismissible(
      key: ValueKey('character-${character.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: InkWell(
        onTap: () => context.push('/characters/${character.id}'),
        // Long press opens the overflow menu (chat / edit / export / delete).
        onLongPress: () => _showLongPressMenu(context, ref),
        child: SizedBox(
          height: AppTheme.navPageRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: _buildListAvatar(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        character.name,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        character.description.isNotEmpty
                            ? character.description
                            : l10n.description,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Overflow menu shown on long-press of a character row.
  void _showLongPressMenu(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final box = context.findRenderObject() as RenderBox?;
    final rect =
        box == null ? Rect.zero : box.localToGlobal(Offset.zero) & box.size;
    final screen = MediaQuery.sizeOf(context);

    showMenu<_CharacterMenuItem>(
      context: context,
      position: RelativeRect.fromLTRB(
        rect.right,
        rect.top,
        screen.width - rect.left,
        screen.height - rect.bottom,
      ),
      items: [
        _popupItem(_CharacterMenuItem.chat, Icons.chat, l10n.startChat),
        _popupItem(_CharacterMenuItem.edit, Icons.edit, l10n.edit),
        _popupItem(
            _CharacterMenuItem.export, Icons.file_upload, l10n.exportChat),
        _popupItem(_CharacterMenuItem.delete, Icons.delete, l10n.delete,
            isDestructive: true),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case _CharacterMenuItem.chat:
          _startChat(context, ref);
          break;
        case _CharacterMenuItem.edit:
          context.push('/characters/${character.id}/edit');
          break;
        case _CharacterMenuItem.export:
          break;
        case _CharacterMenuItem.delete:
          _confirmDelete(context, ref);
          break;
      }
    });
  }

  PopupMenuItem<_CharacterMenuItem> _popupItem(
      _CharacterMenuItem value, IconData icon, String label,
      {bool isDestructive = false}) {
    return PopupMenuItem<_CharacterMenuItem>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDestructive ? Colors.red : null),
          const SizedBox(width: 10),
          Text(
            label,
            style: isDestructive
                ? const TextStyle(color: Colors.red)
                : const TextStyle(color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Future<void> _startChat(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);

    try {
      final chatId =
          await ref.read(activeChatProvider.notifier).createChat(character.id);
      if (chatId != null && context.mounted) {
        context.push('/chat/$chatId');
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.error)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.error}: $e')),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCharacter),
        content: Text(l10n.deleteCharacterConfirmation(character.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(characterListProvider.notifier)
                  .deleteCharacter(character.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
          content: Text(l10n.characterDeleted),
          duration: const Duration(seconds: 1),
        ),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  Widget _buildListAvatar() {
    if (character.assets?.avatarPath != null) {
      return CharacterAvatarCircle(
        imagePath: character.assets!.avatarPath!,
        radius: 28,
      );
    }

    final icon = _getCharacterIcon(character);
    final color = _getCharacterColor(character);

    return CircleAvatar(
      radius: 28,
      backgroundColor: color,
      child: Icon(
        icon,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  IconData _getCharacterIcon(Character character) {
    switch (character.id) {
      case 'builtin_coding_assistant':
        return Icons.code;
      case 'builtin_image_gen_assistant':
        return Icons.image;
      case 'builtin_xiaohongshu_copywriter':
        return Icons.edit_note;
      default:
        return Icons.person;
    }
  }

  Color _getCharacterColor(Character character) {
    switch (character.id) {
      case 'builtin_coding_assistant':
        return const Color(0xFF2196F3);
      case 'builtin_image_gen_assistant':
        return const Color(0xFFE91E63);
      case 'builtin_xiaohongshu_copywriter':
        return const Color(0xFFFF5722);
      default:
        return AppTheme.primaryColor;
    }
  }
}
