import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/ask/controller/ask_providers.dart';
import 'package:personaltskmng/ask/models/ask_chat.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// Full screen listing all Ask AI conversations under `/browse/ask`.
class ChatsListPage extends ConsumerStatefulWidget {
  const ChatsListPage({super.key});

  @override
  ConsumerState<ChatsListPage> createState() => _ChatsListPageState();
}

class _ChatsListPageState extends ConsumerState<ChatsListPage> {
  final TextEditingController _search = TextEditingController();
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(() {
      setState(() => _filter = _search.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0 && now.day == dt.day) {
      return 'Today';
    } else if (diff.inDays <= 1 || (diff.inDays <= 2 && now.day != dt.day)) {
      return 'Yesterday';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Future<void> _deleteWithUndo(AskChatHeader header) async {
    final store = ref.read(chatStoreProvider);
    final fullChat = await store.load(header.id);
    await ref.read(chatListProvider.notifier).delete(header.id);

    if (!mounted || fullChat == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(header.title),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await store.save(fullChat);
            if (mounted) {
              ref.read(chatListProvider.notifier).reload();
            }
          },
        ),
      ),
    );
  }

  Future<void> _showRenameDialog(AskChatHeader header) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: header.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.askRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: header.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      final store = ref.read(chatStoreProvider);
      final chat = await store.load(header.id);
      if (chat != null) {
        await store.save(chat.copyWith(title: newTitle, updatedAt: DateTime.now()));
        ref.read(chatListProvider.notifier).reload();
      }
    }
  }

  Future<void> _showChatActions(AskChatHeader header) async {
    final l10n = context.l10n;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l10n.askRename),
              onTap: () => Navigator.pop(context, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text(l10n.askCopyChat),
              onTap: () => Navigator.pop(context, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(l10n.askDeleteChat,
                  style: const TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'rename') {
      await _showRenameDialog(header);
    } else if (action == 'copy') {
      final store = ref.read(chatStoreProvider);
      final chat = await store.load(header.id);
      if (chat != null) {
        final buffer = StringBuffer();
        buffer.writeln(chat.title);
        buffer.writeln();
        for (final m in chat.messages) {
          final sender = m.role.name == 'user' ? 'User' : 'Assistant';
          buffer.writeln('$sender: ${m.text}');
          buffer.writeln();
        }
        await Clipboard.setData(ClipboardData(text: buffer.toString()));
        if (mounted) showAppSnackBar(context, l10n.askCopiedChat);
      }
    } else if (action == 'delete') {
      await _deleteWithUndo(header);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chatsAsync = ref.watch(chatListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(l10n.askChatsTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              if (val == 'settings') {
                context.push(AppRoutes.settings);
              } else if (val == 'deleteAll') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(l10n.askDeleteAllChats),
                    content: Text(l10n.askDeleteAllConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(chatListProvider.notifier).deleteAll();
                }
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.askSettingsAction),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'deleteAll',
                child: Row(
                  children: [
                    const Icon(Icons.delete_sweep_outlined,
                        size: 20, color: Colors.red),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.askDeleteAllChats,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(BrowsePaths.askNew()),
        tooltip: l10n.askNewChat,
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formMaxWidth,
          ),
          child: Column(
            children: [
              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: l10n.askSearchPlaceholder,
                    isDense: true,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => _search.clear(),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: chatsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (chats) {
                    final filtered = _filter.isEmpty
                        ? chats
                        : chats.where((c) {
                            final matchTitle =
                                c.title.toLowerCase().contains(_filter);
                            final matchSnippet =
                                c.snippet.toLowerCase().contains(_filter);
                            final matchAnchor = c.anchors
                                .any((a) => a.key.contains(_filter));
                            return matchTitle || matchSnippet || matchAnchor;
                          }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 56,
                                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                l10n.askEmptyTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                l10n.askEmptyMessage,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              FilledButton.tonal(
                                onPressed: () =>
                                    context.push(BrowsePaths.askNew()),
                                child: Text(l10n.askAboutAnAyah),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final header = filtered[index];
                        return Dismissible(
                          key: Key(header.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: AlignmentDirectional.centerEnd,
                            padding: const EdgeInsetsDirectional.only(
                              end: AppSpacing.lg,
                            ),
                            color: Colors.red,
                            child: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                          ),
                          onDismissed: (_) => _deleteWithUndo(header),
                          child: Card(
                            elevation: 0,
                            color: scheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.control),
                              side: BorderSide(
                                color: scheme.outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                            child: InkWell(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.control),
                              onTap: () => context.push(
                                BrowsePaths.askChat(header.id),
                              ),
                              onLongPress: () => _showChatActions(header),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            header.title,
                                            style: theme.textTheme.titleSmall
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Text(
                                          _formatDate(header.updatedAt),
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (header.anchors.isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Wrap(
                                        spacing: 4,
                                        children: [
                                          for (final a in header.anchors.take(3))
                                            DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: scheme.primaryContainer
                                                    .withValues(alpha: 0.6),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                child: Text(
                                                  a.key,
                                                  style: theme
                                                      .textTheme.labelSmall
                                                      ?.copyWith(
                                                    color: scheme
                                                        .onPrimaryContainer,
                                                    fontWeight:
                                                        FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                    if (header.snippet.isNotEmpty) ...[
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        header.snippet,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

