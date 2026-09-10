import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:native_tavern/core/utils/neko_date_format.dart';
import 'package:native_tavern/data/models/chat.dart';
import 'package:native_tavern/data/models/character.dart';
import 'package:native_tavern/data/models/group.dart';
import 'package:native_tavern/data/repositories/character_repository.dart';
import 'package:native_tavern/data/repositories/chat_repository.dart';
import 'package:native_tavern/data/repositories/group_repository.dart';
import 'package:native_tavern/l10n/generated/app_localizations.dart';
import 'package:native_tavern/presentation/providers/chat_providers.dart';
import 'package:native_tavern/presentation/router/app_router.dart';
import 'package:native_tavern/presentation/theme/app_theme.dart';
import 'package:native_tavern/presentation/widgets/common/character_avatar_image.dart';
import 'package:native_tavern/presentation/widgets/common/group_avatar.dart';

/// Home screen showing recent chats
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh chat list when screen is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(pagedChatsProvider);
      ref.invalidate(_groupPresentationProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh chat list when returning to the app
      ref.invalidate(pagedChatsProvider);
      ref.invalidate(_groupPresentationProvider);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh chat list whenever dependencies change (e.g., when navigating back)
    ref.invalidate(pagedChatsProvider);
    ref.invalidate(_groupPresentationProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups),
            tooltip: l10n.groupChats,
            onPressed: () => context.push(AppRoutes.groups),
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: l10n.import,
            onPressed: () => context.push(AppRoutes.import_),
          ),
        ],
      ),
      body: const _ChatListView(),
    );
  }
}

class _ChatListView extends ConsumerStatefulWidget {
  const _ChatListView();

  @override
  ConsumerState<_ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends ConsumerState<_ChatListView> {
  /// Chat ids that have been swiped away this frame. Keeping them here lets
  /// the Dismissible leave the tree synchronously before the async repo
  /// delete finishes.
  final Set<String> _dismissedIds = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chatsAsync = ref.watch(pagedChatsProvider);

    return chatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(l10n.errorLoadingChats(error.toString())),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(allChatsProvider),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
      data: (chats) {
        final visible = chats.where((c) => !_dismissedIds.contains(c.id));
        if (visible.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 80,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noChatsYet,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.startNewConversation,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textMuted,
                      ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.characters),
                  icon: const Icon(Icons.people),
                  label: Text(l10n.browseCharacters),
                ),
              ],
            ),
          );
        }

        // Neko-style rounded card wrapping ONLY the visible dialogs: the card
        // height follows the number of chats (shrink-wrapped), the page
        // background stays around it, and the whole thing scrolls.
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.extentAfter < 600) {
              ref.read(pagedChatsProvider.notifier).loadMore();
            }
            return false;
          },
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(pagedChatsProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
              child: Material(
                color: context.neko.card,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (final chat in visible)
                      _ChatListTile(
                        chat: chat,
                        onDismissed: () => _dismissChat(chat.id),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _dismissChat(String chatId) async {
    // Remove from local tree this frame so the Dismissible doesn't assert.
    setState(() => _dismissedIds.add(chatId));
    final l10n = AppLocalizations.of(context);
    await ref.read(chatRepositoryProvider).deleteChat(chatId);
    ref.invalidate(allChatsProvider);
    ref.invalidate(pagedChatsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.chatDeleted),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}

class _ChatListTile extends ConsumerWidget {
  final Chat chat;
  final VoidCallback onDismissed;

  const _ChatListTile({required this.chat, required this.onDismissed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final characterAsync =
        ref.watch(_characterForChatProvider(chat.characterId));
    final groupPresentationAsync = chat.groupId == null
        ? null
        : ref.watch(_groupPresentationProvider(chat.groupId!));
    final lastMessageAsync = ref.watch(_lastMessageProvider(chat.id));

    // Neko-style compact dialog row (mirrors Telegram DialogCell: 52dp round
    // avatar left, bold title, grey preview, time top-right, no card surface).
    return Dismissible(
      key: ValueKey('chat-${chat.id}'),
      direction: DismissDirection.endToStart,
      background: _buildDeleteBackground(context, Alignment.centerRight),
      onDismissed: (_) => onDismissed(),
      child: InkWell(
        onTap: () {
          // Navigate to chat screen
          context.push('/chat/${chat.id}');
        },
        // Neko DialogCell is exactly 70dp tall (2-line layout). Enforce a
        // fixed row height so it always matches regardless of text metrics.
        child: SizedBox(
          height: AppTheme.chatRowHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: groupPresentationAsync != null
                      ? groupPresentationAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, __) => const GroupAvatar(characters: []),
                          data: (presentation) => GroupAvatar(
                            characters: presentation?.characters ?? const [],
                          ),
                        )
                      : characterAsync.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, __) =>
                              const CircleAvatar(child: Icon(Icons.person)),
                          data: _buildCharacterAvatar,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    // Title occupies the upper half of the row, preview the
                    // lower half (each half vertically centers its own line).
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: groupPresentationAsync != null
                                    ? groupPresentationAsync.when(
                                        loading: () => Text(
                                          l10n.loading,
                                          style: _titleStyle(context),
                                        ),
                                        error: (_, __) => Text(
                                          chat.title,
                                          style: _titleStyle(context),
                                        ),
                                        data: (presentation) => Text(
                                          presentation?.group.name ??
                                              chat.title,
                                          style: _titleStyle(context),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      )
                                    : characterAsync.when(
                                        loading: () => Text(l10n.loading,
                                            style: _titleStyle(context)),
                                        error: (_, __) => Text(
                                          chat.title,
                                          style: _titleStyle(context),
                                        ),
                                        data: (character) => Text(
                                          character?.name ?? chat.title,
                                          style: _titleStyle(context),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(context, chat.updatedAt),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: AppTheme.textMuted,
                                      fontSize: 12,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: lastMessageAsync.when(
                            loading: () => const Text('...'),
                            error: (_, __) => Text(
                              l10n.noMessages,
                              style: _previewStyle(context),
                            ),
                            data: (message) => Text(
                              message?.content ?? l10n.noMessagesYet,
                              style: _previewStyle(context),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
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

  /// Red right-edge delete background shown while the row is swiped left.
  Widget _buildDeleteBackground(BuildContext context, Alignment align) {
    return Container(
      color: Colors.red,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  TextStyle _titleStyle(BuildContext context) {
    return TextStyle(
      color: context.neko.textPrimary,
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
    );
  }

  TextStyle _previewStyle(BuildContext context) {
    return TextStyle(
      color: AppTheme.textSecondary,
      fontSize: 13,
      height: 1.2,
    );
  }

  Widget _buildCharacterAvatar(Character? character) {
    final avatarPath = character?.assets?.avatarPath;
    if (avatarPath != null && avatarPath.isNotEmpty) {
      return CharacterAvatarCircle(
        imagePath: avatarPath,
        errorBuilder: (_, __, ___) => _characterFallback(character),
      );
    }
    return _characterFallback(character);
  }

  Widget _characterFallback(Character? character) {
    return CircleAvatar(
      backgroundColor: AppTheme.accentColor.withValues(alpha: 0.2),
      child: Text(
        character?.name.isNotEmpty == true
            ? character!.name.characters.first.toUpperCase()
            : '?',
        style: const TextStyle(color: AppTheme.accentColor),
      ),
    );
  }

  /// Nekogram's `stringForMessageListDate()`: clock today (and for yesterday
  /// younger than 8h), weekday within the last week, then a plain date.
  /// Deliberately has no "Yesterday" label — upstream shows the weekday.
  String _formatTime(BuildContext context, DateTime dateTime) {
    return NekoDateFormat.messageListDate(
      dateTime,
      locale: Localizations.localeOf(context).toString(),
    );
  }
}

/// Provider to get character for a chat
final _characterForChatProvider =
    FutureProvider.family((ref, String characterId) async {
  final repo = ref.watch(characterRepositoryProvider);
  return repo.getCharacter(characterId);
});

class _GroupPresentation {
  const _GroupPresentation({required this.group, required this.characters});

  final Group group;
  final List<Character?> characters;
}

final _groupPresentationProvider =
    FutureProvider.family<_GroupPresentation?, String>((ref, groupId) async {
  final groupRepo = ref.watch(groupRepositoryProvider);
  final characterRepo = ref.watch(characterRepositoryProvider);
  final group = await groupRepo.getGroup(groupId);
  if (group == null) return null;
  final characters = await Future.wait(
    group.sortedMembers.take(4).map(
          (member) => characterRepo.getCharacter(member.characterId),
        ),
  );
  return _GroupPresentation(group: group, characters: characters);
});

/// Provider to get last message for a chat
final _lastMessageProvider = FutureProvider.family((ref, String chatId) async {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.getLastMessage(chatId);
});
