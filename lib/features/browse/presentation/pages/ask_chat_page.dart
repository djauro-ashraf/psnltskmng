import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ask/controller/ask_providers.dart';
import 'package:personaltskmng/ask/models/ask_chat.dart';
import 'package:personaltskmng/ask/models/ask_context.dart';
import 'package:personaltskmng/ask/models/ask_preset.dart';
import 'package:personaltskmng/ask/prompts/ask_prompts.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/go_to_sheet.dart';
import 'package:personaltskmng/quran_data/controller/ayah_copy_loader.dart';
import 'package:personaltskmng/quran_data/models/ayah_copy.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// Full screen Ask AI conversation thread under `/browse/ask/:id` or `/browse/ask/new`.
class AskChatPage extends ConsumerStatefulWidget {
  const AskChatPage({
    super.key,
    this.chatId,
    this.initialAyah,
    this.initialPrompt,
    this.initialFocusText,
  });

  final String? chatId;
  final AyahRef? initialAyah;
  final String? initialPrompt;
  final String? initialFocusText;

  @override
  ConsumerState<AskChatPage> createState() => _AskChatPageState();
}

class _AskChatPageState extends ConsumerState<AskChatPage> {
  late String _activeChatId;
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _contextExpanded = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _activeChatId = widget.chatId ?? 'chat_${DateTime.now().millisecondsSinceEpoch}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initChat();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    if (_initialized) return;
    _initialized = true;

    // Check if loading existing chat
    final existing = await ref.read(chatStoreProvider).load(_activeChatId);
    if (existing != null) {
      if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
        _input.text = widget.initialPrompt!;
      }
      return;
    }

    // New chat setup
    AskContext? initialContext;
    if (widget.initialAyah != null) {
      initialContext = await _loadContextForAyah(
        widget.initialAyah!,
        focusText: widget.initialFocusText,
      );
    }

    final newChat = AskChat(
      id: _activeChatId,
      title: initialContext != null
          ? 'Ayah ${initialContext.ayah.key}'
          : 'New Chat',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      anchors: initialContext != null ? [initialContext.ayah] : const [],
      pinned: initialContext != null ? [initialContext] : const [],
      messages: const [],
    );

    await ref
        .read(chatDetailProvider(_activeChatId).notifier)
        .createChat(newChat);

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _input.text = widget.initialPrompt!;
    }
  }

  Future<AskContext?> _loadContextForAyah(
    AyahRef ayah, {
    String? focusText,
  }) async {
    try {
      final inputs = await AyahCopyLoader.load(
        ref: ref,
        range: AyahRange(ayah, ayah),
        recipe: const CopyRecipe(
          parts: {
            CopyPart.arabic,
            CopyPart.translation,
            CopyPart.words,
            CopyPart.tafsir,
          },
        ),
      );
      if (inputs.isEmpty) return null;
      final input = inputs.first;

      final wordsGlosses = <String>[];
      for (final w in input.ayah.words) {
        if (w.arabic.isNotEmpty && w.gloss.isNotEmpty) {
          wordsGlosses.add('${w.arabic} = ${w.gloss}');
        }
      }

      String? tafsirText;
      bool truncated = false;
      if (input.tafsir != null && input.tafsir!.paragraphs.isNotEmpty) {
        final full = input.tafsir!.paragraphs.join('\n\n');
        if (full.length > AskContext.maxTafsirCharacters) {
          tafsirText = full.substring(0, AskContext.maxTafsirCharacters);
          truncated = true;
        } else {
          tafsirText = full;
        }
      }

      return AskContext(
        ayah: ayah,
        arabic: input.ayah.arabic,
        translation: input.translation?.text,
        translationAuthor: input.translation?.author,
        words: wordsGlosses.isNotEmpty ? wordsGlosses : null,
        tafsirTitle: input.tafsir?.title ?? (input.tafsir != null ? 'Tafsir' : null),
        tafsirCovers: input.tafsir?.covers,
        tafsirText: tafsirText,
        isTafsirTruncated: truncated,
        focusText: focusText,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _attachAnotherAyah() async {
    final stateVal = ref.read(chatDetailProvider(_activeChatId)).value;
    final pinned = stateVal?.chat.pinned ?? [];
    if (pinned.length >= 3) {
      showAppSnackBar(context, context.l10n.askMaxAttachments);
      return;
    }

    final anchor = pinned.isNotEmpty ? pinned.last.ayah : const AyahRef(1, 1);
    final choice = await showGoToSheet(context, place: anchor);
    if (choice is JumpToAyah && mounted) {
      final ctx = await _loadContextForAyah(choice.ayah);
      if (ctx != null && mounted) {
        await ref
            .read(chatDetailProvider(_activeChatId).notifier)
            .attachContext(ctx);
        setState(() => _contextExpanded = true);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? customText]) async {
    final text = customText ?? _input.text.trim();
    if (text.isEmpty) return;

    if (customText == null) {
      _input.clear();
    }

    final notifier = ref.read(chatDetailProvider(_activeChatId).notifier);
    await notifier.sendMessage(text);
    _scrollToBottom();
  }

  Future<void> _showRenameDialog(AskChat chat) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: chat.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.askRenameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: chat.title),
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
      await ref
          .read(chatDetailProvider(_activeChatId).notifier)
          .rename(newTitle);
    }
  }

  Future<void> _copyFullChat(AskChat chat) async {
    final buffer = StringBuffer();
    buffer.writeln(chat.title);
    buffer.writeln('==============================');
    for (final m in chat.messages) {
      final sender = m.role.name == 'user' ? 'You' : 'Assistant';
      buffer.writeln('$sender (${m.createdAt.hour}:${m.createdAt.minute}):');
      buffer.writeln(m.text);
      buffer.writeln();
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) showAppSnackBar(context, context.l10n.askCopiedChat);
  }

  Widget _buildContextCard(AskChat chat) {
    if (chat.pinned.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.control),
            onTap: () => setState(() => _contextExpanded = !_contextExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      [
                        for (final c in chat.pinned)
                          '${c.ayah.key}${c.translationAuthor != null ? " (${c.translationAuthor})" : ""}',
                      ].join(' · '),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _contextExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_contextExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.sm),
                  for (final c in chat.pinned) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ayah ${c.ayah.key}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(
                            BrowsePaths.readAyah(c.ayah),
                          ),
                          child: const Text('Read in Mushaf'),
                        ),
                      ],
                    ),
                    if (c.arabic.isNotEmpty)
                      Text(
                        c.arabic,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontFamily: AppTheme.serif,
                          height: 1.6,
                        ),
                      ),
                    if (c.translation != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        c.translation!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (c.focusText != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Focus: "${c.focusText}"',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final refs = AskPrompts.findReferences(text);

    if (refs.isEmpty) {
      return Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
      );
    }

    final spans = <InlineSpan>[];
    int current = 0;
    for (final r in refs) {
      if (r.start > current) {
        spans.add(TextSpan(text: text.substring(current, r.start)));
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ActionChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
              label: Text(
                r.ref.key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              onPressed: () => context.push(BrowsePaths.readAyah(r.ref)),
            ),
          ),
        ),
      );
      current = r.end;
    }
    if (current < text.length) {
      spans.add(TextSpan(text: text.substring(current)));
    }

    return Text.rich(
      TextSpan(children: spans),
      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detailAsync = ref.watch(chatDetailProvider(_activeChatId));

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(
          detailAsync.value?.chat.title ?? l10n.askAiTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (detailAsync.value?.chat != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) async {
                final chat = detailAsync.value!.chat;
                if (val == 'rename') {
                  await _showRenameDialog(chat);
                } else if (val == 'copy') {
                  await _copyFullChat(chat);
                } else if (val == 'delete') {
                  await ref.read(chatListProvider.notifier).delete(chat.id);
                  if (context.mounted) context.pop();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(l10n.askRename),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      const Icon(Icons.copy_outlined, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(l10n.askCopyChat),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline,
                          size: 20, color: Colors.red),
                      const SizedBox(width: AppSpacing.sm),
                      Text(l10n.askDeleteChat,
                          style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formMaxWidth,
          ),
          child: Column(
            children: [
              detailAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (stateVal) => stateVal == null
                    ? const SizedBox.shrink()
                    : _buildContextCard(stateVal.chat),
              ),
              Expanded(
                child: detailAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text(e.toString())),
                  data: (stateVal) {
                    final chat = stateVal?.chat;
                    if (chat == null || chat.messages.isEmpty) {
                      // Preset chips for empty chat
                      final ctx = chat?.pinned.isNotEmpty == true
                          ? chat!.pinned.first
                          : null;
                      final availablePresets = [
                        for (final p in AskPreset.all)
                          if (ctx == null || p.isAvailable(ctx)) p,
                      ];

                      return Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                size: 48,
                                color: scheme.primary,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                l10n.askEmptyTitle,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                l10n.askEmptyMessage,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                alignment: WrapAlignment.center,
                                children: [
                                  for (final preset in availablePresets)
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.lightbulb_outline,
                                        size: 16,
                                      ),
                                      label: Text(preset.defaultLabel),
                                      onPressed: () =>
                                          _send(preset.instruction),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final isGenerating = stateVal?.isGenerating ?? false;
                    final messages = chat.messages;

                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: messages.length +
                          (messages.isNotEmpty &&
                                  messages.last.role == AiRole.assistant &&
                                  !isGenerating
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if (index == messages.length) {
                          // Follow up chips
                          return Padding(
                            padding:
                                const EdgeInsets.only(top: AppSpacing.sm),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final f in AskPreset.followUps)
                                  ActionChip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      f,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    onPressed: isGenerating
                                        ? null
                                        : () => _send(
                                              AskPreset
                                                  .instructionForFollowUp(f),
                                            ),
                                  ),
                              ],
                            ),
                          );
                        }

                        final msg = messages[index];
                        final isUser = msg.role == AiRole.user;
                        final isLastAssistant = !isUser &&
                            (index == messages.length - 1 ||
                                (index == messages.length - 2 &&
                                    messages.last.role == AiRole.user));

                        return Align(
                          alignment: isUser
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.82,
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest
                                      .withValues(alpha: 0.7),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16),
                                topRight: const Radius.circular(16),
                                bottomLeft: isUser
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                                bottomRight: isUser
                                    ? Radius.zero
                                    : const Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMessageContent(msg.text),
                                if (msg.interrupted)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '(Interrupted)',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: scheme.error,
                                      ),
                                    ),
                                  ),
                                if (!isUser && !isGenerating)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          iconSize: 16,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(Icons.copy_outlined),
                                          tooltip: 'Copy',
                                          onPressed: () {
                                            Clipboard.setData(
                                              ClipboardData(text: msg.text),
                                            );
                                            showAppSnackBar(
                                              context,
                                              'Copied to clipboard',
                                            );
                                          },
                                        ),
                                        if (isLastAssistant) ...[
                                          const SizedBox(width: AppSpacing.md),
                                          IconButton(
                                            iconSize: 16,
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                            icon: const Icon(
                                              Icons.refresh_outlined,
                                            ),
                                            tooltip: l10n.askRegenerate,
                                            onPressed: () => ref
                                                .read(chatDetailProvider(
                                                        _activeChatId)
                                                    .notifier)
                                                .regenerateLast(),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Inline error banner
              if (detailAsync.value?.error != null)
                Container(
                  color: scheme.errorContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 18, color: scheme.onErrorContainer),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          detailAsync.value!.error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(chatDetailProvider(_activeChatId).notifier)
                            .regenerateLast(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),

              // Input bar
              Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border(
                    top: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          tooltip: l10n.askAttachAyah,
                          onPressed: _attachAnotherAyah,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: l10n.askInputPlaceholder,
                              isDense: true,
                              border: InputBorder.none,
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        if (detailAsync.value?.isGenerating == true)
                          IconButton(
                            icon: const Icon(Icons.stop_circle, color: Colors.red),
                            tooltip: 'Stop',
                            onPressed: () => ref
                                .read(chatDetailProvider(_activeChatId).notifier)
                                .stopStreaming(),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.arrow_upward_rounded),
                            color: scheme.primary,
                            onPressed: () => _send(),
                          ),
                      ],
                    ),
                    Text(
                      l10n.askDisclaimer,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

