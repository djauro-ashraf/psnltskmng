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
import 'package:personaltskmng/features/browse/presentation/widgets/ask_chat_text.dart';
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
      final next = _search.text.trim().toLowerCase();
      if (next != _filter) setState(() => _filter = next);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// "Today", "Yesterday", or the date in the reader's format. Counted in
  /// calendar days, not in hours: 30 hours ago can be the day before yesterday.
  String _dayLabel(DateTime when) {
    final l10n = context.l10n;
    final now = DateTime.now();
    // As UTC dates: a day that has 23 or 25 hours (clocks changing) is still
    // one day.
    final days = DateTime.utc(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime.utc(when.year, when.month, when.day)).inDays;
    if (days == 0) return l10n.askToday;
    if (days == 1) return l10n.askYesterday;
    return MaterialLocalizations.of(context).formatShortDate(when);
  }

  /// Deletes the chat (it leaves the list at once) and offers to put it back.
  Future<void> _deleteWithUndo(AskChatHeader header) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(chatListProvider.notifier);
    final removed = await notifier.remove(header.id);
    if (!mounted || removed == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(header.title, maxLines: 1),
          action: SnackBarAction(
            label: l10n.askUndo,
            onPressed: () => unawaited(notifier.restore(removed)),
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
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.settingsSave),
          ),
        ],
      ),
    );
    controller.dispose();

    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      await ref.read(chatListProvider.notifier).rename(header.id, newTitle);
    }
  }

  Future<void> _copyChat(AskChatHeader header) async {
    final l10n = context.l10n;
    final chat = await ref.read(chatStoreProvider).load(header.id);
    if (chat == null || !mounted) return;
    await Clipboard.setData(ClipboardData(text: askChatText(chat, l10n)));
    if (mounted) showAppSnackBar(context, l10n.askCopiedChat);
  }

  Future<void> _showChatActions(AskChatHeader header) async {
    final l10n = context.l10n;
    final error = Theme.of(context).colorScheme.error;
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
              leading: Icon(Icons.delete_outline, color: error),
              title: Text(
                l10n.askDeleteChat,
                style: TextStyle(color: error),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    switch (action) {
      case 'rename':
        await _showRenameDialog(header);
      case 'copy':
        await _copyChat(header);
      case 'delete':
        await _deleteWithUndo(header);
    }
  }

  Future<void> _confirmDeleteAll() async {
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.askDeleteAllChats),
        content: Text(l10n.askDeleteAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.aiSavedKeyDelete),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(chatListProvider.notifier).deleteAll();
    }
  }

  /// No chat at all (an invitation to ask), or none that fits the search.
  Widget _buildEmpty({required bool searching}) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching
                  ? Icons.search_off_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 56,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              searching ? l10n.askNoMatches : l10n.askEmptyTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!searching) ...[
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
                onPressed: () => context.push(BrowsePaths.askNew()),
                child: Text(l10n.askAboutAnAyah),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(AskChatHeader header) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () => context.push(BrowsePaths.askChat(header.id)),
        onLongPress: () => unawaited(_showChatActions(header)),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      header.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _dayLabel(header.updatedAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  // The same actions as a long press, where they can be seen.
                  SizedBox.square(
                    dimension: 32,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      iconSize: 20,
                      icon: const Icon(Icons.more_vert),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).showMenuTooltip,
                      onPressed: () => unawaited(_showChatActions(header)),
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
                          color: scheme.primaryContainer.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            a.key,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (header.snippet.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppSpacing.sm,
                  ),
                  child: Text(
                    header.snippet,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final chatsAsync = ref.watch(chatListProvider);
    final hasChats = chatsAsync.value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(l10n.askChatsTitle),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'settings') {
                unawaited(context.push(AppRoutes.settings));
              } else if (val == 'deleteAll') {
                unawaited(_confirmDeleteAll());
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
                enabled: hasChats,
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_sweep_outlined,
                      size: 20,
                      color: hasChats ? scheme.error : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      l10n.askDeleteAllChats,
                      style: TextStyle(color: hasChats ? scheme.error : null),
                    ),
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
                    fillColor: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _filter.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _search.clear,
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
                        : [
                            for (final c in chats)
                              if (c.title.toLowerCase().contains(_filter) ||
                                  c.snippet.toLowerCase().contains(_filter) ||
                                  c.anchors.any((a) => a.key.contains(_filter)))
                                c,
                          ];

                    if (filtered.isEmpty) {
                      return _buildEmpty(searching: chats.isNotEmpty);
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
                          key: ValueKey(header.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: AlignmentDirectional.centerEnd,
                            padding: const EdgeInsetsDirectional.only(
                              end: AppSpacing.lg,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.error,
                              borderRadius: BorderRadius.circular(
                                AppRadius.control,
                              ),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: scheme.onError,
                            ),
                          ),
                          onDismissed: (_) =>
                              unawaited(_deleteWithUndo(header)),
                          child: _buildCard(header),
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
