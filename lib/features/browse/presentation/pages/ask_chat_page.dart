import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/ask/controller/ask_providers.dart';
import 'package:personaltskmng/ask/models/ask_chat.dart';
import 'package:personaltskmng/ask/models/ask_context.dart';
import 'package:personaltskmng/ask/models/ask_preset.dart';
import 'package:personaltskmng/ask/prompts/ask_markdown.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/ask_chat_text.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/go_to_sheet.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/quran_data/controller/ayah_copy_loader.dart';
import 'package:personaltskmng/quran_data/models/ayah_copy.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// What a preset chip says, in the language of the screen.
String _presetLabel(AppLocalizations l10n, AskPresetId id) => switch (id) {
  AskPresetId.explainSimply => l10n.askPresetExplainSimply,
  AskPresetId.explainDeeper => l10n.askPresetExplainDeeper,
  AskPresetId.simplifyTafsir => l10n.askPresetSimplifyTafsir,
  AskPresetId.wordsGrammar => l10n.askPresetWordsGrammar,
  AskPresetId.lessons => l10n.askPresetLessons,
  AskPresetId.helpRemember => l10n.askPresetHelpRemember,
};

/// What a follow-up chip says, in the language of the screen.
String _followUpLabel(AppLocalizations l10n, AskFollowUp f) => switch (f) {
  AskFollowUp.shorter => l10n.askFollowUpShorter,
  AskFollowUp.moreDetail => l10n.askFollowUpMoreDetail,
  AskFollowUp.example => l10n.askFollowUpExample,
  AskFollowUp.french => l10n.askFollowUpFrench,
  AskFollowUp.arabic => l10n.askFollowUpArabic,
};

/// Full screen Ask AI conversation thread under `/browse/ask/:id` or `/browse/ask/new`.
///
/// A new chat is kept only from its first message: one that is opened and left
/// is not in the list.
class AskChatPage extends ConsumerStatefulWidget {
  const AskChatPage({
    super.key,
    this.chatId,
    this.initialAyah,
    this.initialPrompt,
    this.initialFocusText,
    this.initialTafsirSourceId,
  });

  final String? chatId;
  final AyahRef? initialAyah;

  /// A question put in the box (not sent).
  final String? initialPrompt;

  /// The words the reader had selected: part of what is attached for a new
  /// chat, quoted in the box for a chat that goes on.
  final String? initialFocusText;

  /// The tafsir the reader was reading when asking (its source id); the ayah
  /// is attached with that one's passage. Null: the first one downloaded.
  final String? initialTafsirSourceId;

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
    _activeChatId =
        widget.chatId ?? 'chat_${DateTime.now().millisecondsSinceEpoch}';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_initChat());
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _fillInput(String text) {
    if (text.isEmpty) return;
    _input.text = text;
    _input.selection = TextSelection.collapsed(offset: text.length);
  }

  Future<void> _initChat() async {
    if (_initialized) return;
    _initialized = true;

    final prompt = widget.initialPrompt?.trim() ?? '';
    final focus = widget.initialFocusText?.trim() ?? '';

    // Going on with a chat that exists?
    final existing = await ref.read(chatStoreProvider).load(_activeChatId);
    if (!mounted) return;
    if (existing != null) {
      // What was selected is quoted in the box, to ask about.
      _fillInput(
        [
          if (focus.isNotEmpty) '“$focus”',
          if (prompt.isNotEmpty) prompt,
        ].join('\n'),
      );
      return;
    }

    // New chat setup
    AskContext? initialContext;
    if (widget.initialAyah != null) {
      initialContext = await _loadContextForAyah(
        widget.initialAyah!,
        focusText: focus.isEmpty ? null : focus,
        tafsirSourceId: widget.initialTafsirSourceId,
      );
      if (!mounted) return;
    }

    final l10n = context.l10n;
    final newChat = AskChat(
      id: _activeChatId,
      title: initialContext != null
          ? l10n.askAyahTitle(initialContext.ayah.key)
          : l10n.askNewChat,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      anchors: initialContext != null ? [initialContext.ayah] : const [],
      pinned: initialContext != null ? [initialContext] : const [],
      messages: const [],
    );

    await ref
        .read(chatDetailProvider(_activeChatId).notifier)
        .createChat(newChat);
    if (!mounted) return;
    _fillInput(prompt);
  }

  Future<AskContext?> _loadContextForAyah(
    AyahRef ayah, {
    String? focusText,
    String? tafsirSourceId,
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
        tafsirSourceId: tafsirSourceId,
      );
      if (inputs.isEmpty) return null;
      final input = inputs.first;

      final wordsGlosses = <String>[];
      for (final w in input.ayah.words) {
        if (w.arabic.isNotEmpty && w.gloss.isNotEmpty) {
          wordsGlosses.add('${w.arabic} = ${w.gloss}');
        }
      }

      final full = input.tafsir?.paragraphs.join('\n\n') ?? '';
      final truncated = full.length > AskContext.maxTafsirCharacters;
      final tafsirText = full.isEmpty
          ? null
          : (truncated
                ? full.substring(0, AskContext.maxTafsirCharacters)
                : full);

      return AskContext(
        ayah: ayah,
        arabic: input.ayah.arabic,
        translation: input.translation?.text,
        translationAuthor: input.translation?.author,
        words: wordsGlosses.isNotEmpty ? wordsGlosses : null,
        tafsirTitle:
            input.tafsir?.title ?? (input.tafsir != null ? 'Tafsir' : null),
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
        if (mounted) setState(() => _contextExpanded = true);
      }
    }
  }

  /// The thread follows what is written while the reader is at its end, and is
  /// left alone when the reader scrolled up to read. A message of the reader
  /// always brings the end into view.
  void _followThread(ChatDetailState? before, ChatDetailState? after) {
    if (after == null || after.chat.messages.isEmpty) return;
    final now = after.chat.messages;
    final was = before?.chat.messages ?? const [];
    final grew =
        now.length != was.length ||
        (was.isNotEmpty && now.last.text.length != was.last.text.length);
    if (!grew) return;
    final atEnd =
        !_scroll.hasClients ||
        _scroll.position.maxScrollExtent - _scroll.offset < 160;
    if (!atEnd && now.last.role != AiRole.user) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  /// Sends the box ([preset] null) or an instruction of a chip, named [label] in
  /// the title of a new chat.
  Future<void> _send({String? preset, String? label}) async {
    final state = ref.read(chatDetailProvider(_activeChatId)).value;
    // Not ready, or an answer is being written: the box keeps its text.
    if (state == null || state.isGenerating) return;
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    if (preset == null) _input.clear();

    await ref
        .read(chatDetailProvider(_activeChatId).notifier)
        .sendMessage(text, label: label);
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
      await ref
          .read(chatDetailProvider(_activeChatId).notifier)
          .rename(newTitle);
    }
  }

  Future<void> _confirmDelete(AskChat chat) async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.askDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.aiSavedKeyDelete),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await ref.read(chatDetailProvider(_activeChatId).notifier).deleteChat();
    if (mounted) context.pop();
  }

  Future<void> _copyFullChat(AskChat chat) async {
    final l10n = context.l10n;
    await Clipboard.setData(ClipboardData(text: askChatText(chat, l10n)));
    if (mounted) showAppSnackBar(context, l10n.askCopiedChat);
  }

  /// An answer with the ayah it is about above it, to paste together.
  Future<void> _copyAnswerWithAyah(AskChat chat, String answer) async {
    final l10n = context.l10n;
    final first = chat.pinned.first;
    final parts = <String>[
      first.arabic,
      if (first.translation != null && first.translation!.isNotEmpty)
        first.translation!,
      '(${first.ayah.key})',
      '',
      answer,
    ];
    await Clipboard.setData(ClipboardData(text: parts.join('\n')));
    if (mounted) showAppSnackBar(context, l10n.readerCopied);
  }

  Widget _buildContextCard(AskChat chat) {
    if (chat.pinned.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
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
                          l10n.askAyahTitle(c.ayah.key),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push(BrowsePaths.readAyah(c.ayah)),
                          child: Text(l10n.askReadAyah),
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
                          l10n.askFocusLabel(c.focusText!),
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

  /// The text of a message. An answer shows its bold, italic, bullets and
  /// headings, and its references [2:255] as chips that open the ayah; what the
  /// reader wrote is shown as written.
  Widget _buildMessageContent(String text, {required bool markdown}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final base = theme.textTheme.bodyMedium?.copyWith(height: 1.4);
    if (!markdown) return Text(text, style: base);

    final spans = <InlineSpan>[];
    for (final s in AskMarkdown.parse(text)) {
      final ref = s.ref;
      if (ref == null) {
        spans.add(
          TextSpan(
            text: s.text,
            style: TextStyle(
              fontWeight: s.bold ? FontWeight.bold : null,
              fontStyle: s.italic ? FontStyle.italic : null,
            ),
          ),
        );
        continue;
      }
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ActionChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              label: Text(
                ref.key,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary,
                ),
              ),
              onPressed: () => context.push(BrowsePaths.readAyah(ref)),
            ),
          ),
        ),
      );
    }
    return Text.rich(TextSpan(children: spans), style: base);
  }

  /// The empty chat: the presets that fit what is attached, or, with no ayah
  /// attached, a way to attach one.
  Widget _buildEmpty(AskChat? chat) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ctx = chat != null && chat.pinned.isNotEmpty
        ? chat.pinned.first
        : null;
    final presets = [
      for (final p in AskPreset.all)
        if (p.isAvailable(ctx)) p,
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, size: 48, color: scheme.primary),
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
            if (ctx == null)
              FilledButton.tonalIcon(
                onPressed: _attachAnotherAyah,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(l10n.askAttachAyah),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  for (final preset in presets)
                    ActionChip(
                      avatar: const Icon(Icons.lightbulb_outline, size: 16),
                      label: Text(_presetLabel(l10n, preset.id)),
                      onPressed: () => _send(
                        preset: preset.instruction,
                        label: _presetLabel(l10n, preset.id),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages(ChatDetailState state) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chat = state.chat;
    final isGenerating = state.isGenerating;
    final messages = chat.messages;
    final showFollowUps =
        messages.last.role == AiRole.assistant &&
        !isGenerating &&
        !messages.last.interrupted;

    return SelectionArea(
      child: ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: messages.length + (showFollowUps ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == messages.length) {
            // Follow up chips
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final f in AskFollowUp.values)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        _followUpLabel(l10n, f),
                        style: const TextStyle(fontSize: 12),
                      ),
                      onPressed: () => _send(
                        preset: f.instruction,
                        label: _followUpLabel(l10n, f),
                      ),
                    ),
                ],
              ),
            );
          }

          final msg = messages[index];
          final isUser = msg.role == AiRole.user;
          // Only the last answer can be written anew; a question without an
          // answer has its Retry in the error banner.
          final isLastAssistant = !isUser && index == messages.length - 1;

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
                    : scheme.surfaceContainerHighest.withValues(alpha: 0.7),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                  bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessageContent(msg.text, markdown: !isUser),
                  if (msg.interrupted)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l10n.askInterrupted,
                        style: theme.textTheme.labelSmall?.copyWith(
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
                            tooltip: l10n.readerCopy,
                            onPressed: () {
                              unawaited(
                                Clipboard.setData(ClipboardData(text: msg.text)),
                              );
                              showAppSnackBar(context, l10n.readerCopied);
                            },
                          ),
                          if (chat.pinned.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.md),
                            IconButton(
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.format_quote_outlined),
                              tooltip: l10n.askCopyAyahAndAnswer,
                              onPressed: () =>
                                  _copyAnswerWithAyah(chat, msg.text),
                            ),
                          ],
                          if (isLastAssistant) ...[
                            const SizedBox(width: AppSpacing.md),
                            IconButton(
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const Icon(Icons.refresh_outlined),
                              tooltip: l10n.askRegenerate,
                              onPressed: () => unawaited(
                                ref
                                    .read(
                                      chatDetailProvider(
                                        _activeChatId,
                                      ).notifier,
                                    )
                                    .retry(),
                              ),
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
      ),
    );
  }

  /// The failure of the last answer: in the provider's words, with Retry; a
  /// missing key says so in the reader's language, with the way to the settings.
  Widget _buildErrorBanner(ChatDetailState state) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final missingKey = state.errorKind == AiErrorKind.missingKey;
    final provider = aiProviderInfo(ref.read(askSettingsProvider).provider);
    return Container(
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              missingKey
                  ? l10n.askNoKeyMessage(provider.name)
                  : state.error!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onErrorContainer,
              ),
            ),
          ),
          TextButton(
            onPressed: missingKey
                ? () => context.push(AppRoutes.settings)
                : () => unawaited(
                    ref
                        .read(chatDetailProvider(_activeChatId).notifier)
                        .retry(),
                  ),
            child: Text(missingKey ? l10n.askSettingsAction : l10n.askRetry),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final detailAsync = ref.watch(chatDetailProvider(_activeChatId));
    ref.listen(
      chatDetailProvider(_activeChatId),
      (before, after) => _followThread(before?.value, after.value),
    );

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
                  await _confirmDelete(chat);
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
                      Icon(Icons.delete_outline, size: 20, color: scheme.error),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        l10n.askDeleteChat,
                        style: TextStyle(color: scheme.error),
                      ),
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
                    // The chat is being set up (a new one is made after its
                    // ayah is loaded).
                    if (stateVal == null) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (stateVal.chat.messages.isEmpty) {
                      return _buildEmpty(stateVal.chat);
                    }
                    return _buildMessages(stateVal);
                  },
                ),
              ),

              // Inline error banner
              if (detailAsync.value?.error != null)
                _buildErrorBanner(detailAsync.value!),

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
                            icon: Icon(Icons.stop_circle, color: scheme.error),
                            tooltip: l10n.askStop,
                            onPressed: () => ref
                                .read(
                                  chatDetailProvider(_activeChatId).notifier,
                                )
                                .stopStreaming(),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.arrow_upward_rounded),
                            color: scheme.primary,
                            onPressed: _send,
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
