import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/ai/ai_chat_provider.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_chat.dart';
import 'package:personaltskmng/ai/groq_chat.dart';
import 'package:personaltskmng/ask/data/ask_settings_store.dart';
import 'package:personaltskmng/ask/data/chat_store.dart';
import 'package:personaltskmng/ask/data/in_memory_chat_store.dart';
import 'package:personaltskmng/ask/models/ask_chat.dart';
import 'package:personaltskmng/ask/models/ask_context.dart';
import 'package:personaltskmng/ask/models/ask_message.dart';
import 'package:personaltskmng/ask/models/ask_settings.dart';
import 'package:personaltskmng/ask/prompts/ask_prompts.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';

/// Active [ChatStore]. Overridden in `app/dependencies.dart` with [FileChatStore].
final chatStoreProvider = Provider<ChatStore>((ref) => InMemoryChatStore());

/// Where the assistant's settings are kept. Overridden in
/// `app/dependencies.dart` with the app's preferences.
final askSettingsStoreProvider = Provider<AskSettingsStore>(
  (ref) => MemoryAskSettingsStore(),
);

/// The assistant's settings: on or off, provider, model, language, length. Kept
/// by [askSettingsStoreProvider] at every change.
class AskSettingsNotifier extends Notifier<AskSettings> {
  @override
  AskSettings build() =>
      AskSettings.decode(ref.watch(askSettingsStoreProvider).read());

  void update(AskSettings settings) {
    state = settings;
    unawaited(ref.read(askSettingsStoreProvider).write(settings.encode()));
  }

  void setEnabled(bool enabled) => update(state.copyWith(enabled: enabled));

  void setProvider(String provider) =>
      update(state.copyWith(provider: provider));

  /// An empty [model] goes back to the provider's own default.
  void setModel(String providerId, String model) {
    final updated = Map<String, String>.from(state.models);
    if (model.trim().isEmpty) {
      updated.remove(providerId);
    } else {
      updated[providerId] = model.trim();
    }
    update(state.copyWith(models: updated));
  }

  void setLanguage(String lang) => update(state.copyWith(answerLanguage: lang));

  void setLength(String length) => update(state.copyWith(answerLength: length));
}

final askSettingsProvider = NotifierProvider<AskSettingsNotifier, AskSettings>(
  AskSettingsNotifier.new,
);

/// Whether Ask AI has an API key for the chosen provider. The settings screens
/// invalidate it when a key is saved or removed.
final askHasKeyProvider = FutureProvider<bool>((ref) async {
  final provider = ref.watch(askSettingsProvider.select((s) => s.provider));
  final keys = ref.watch(aiKeyStoreProvider);
  final key = await keys.read(provider);
  return key != null && key.trim().isNotEmpty;
});

/// Whether Ask AI is ready to be used (enabled AND has key). The Ask buttons of
/// the reader are there only then.
final askAvailableProvider = Provider<bool>((ref) {
  final enabled = ref.watch(askSettingsProvider.select((s) => s.enabled));
  final hasKey = ref.watch(askHasKeyProvider).value ?? false;
  return enabled && hasKey;
});

/// Factory returning [AiChatProvider] for a given provider id and model.
final aiChatClientProvider =
    Provider.family<AiChatProvider, ({String providerId, String? model})>((
      ref,
      args,
    ) {
      final keys = ref.watch(aiKeyStoreProvider);
      final providerId = args.providerId;
      final model = args.model;
      if (providerId == 'groq') {
        return GroqChat(
          keys: keys,
          model: (model != null && model.isNotEmpty)
              ? model
              : GroqChat.defaultModel,
        );
      }
      return GeminiChat(
        keys: keys,
        model: (model != null && model.isNotEmpty)
            ? model
            : GeminiChat.defaultModel,
      );
    });

/// Manages the list of all Ask AI chats.
class ChatListNotifier extends AsyncNotifier<List<AskChatHeader>> {
  @override
  Future<List<AskChatHeader>> build() async {
    final store = ref.watch(chatStoreProvider);
    return store.list();
  }

  Future<void> reload() async {
    final store = ref.read(chatStoreProvider);
    final headers = await store.list();
    if (ref.mounted) state = AsyncData(headers);
  }

  Future<void> delete(String id) async {
    await remove(id);
  }

  /// Deletes a chat and gives it back whole, so that it can be [restore]d.
  ///
  /// The chat leaves the list at once (before anything is awaited): a swiped
  /// row has to be gone in the frame it was dismissed in.
  Future<AskChat?> remove(String id) async {
    final store = ref.read(chatStoreProvider);
    final current = state.value;
    if (current != null) {
      state = AsyncData([
        for (final header in current)
          if (header.id != id) header,
      ]);
    }
    final chat = await store.load(id);
    await store.delete(id);
    await reload();
    return chat;
  }

  /// Puts back a chat that [remove] gave.
  Future<void> restore(AskChat chat) async {
    await ref.read(chatStoreProvider).save(chat);
    await reload();
  }

  /// Gives a saved chat another title (the chat open on the screen renames
  /// itself through its own notifier).
  Future<void> rename(String id, String title) async {
    final store = ref.read(chatStoreProvider);
    final chat = await store.load(id);
    if (chat == null) return;
    await store.save(chat.copyWith(title: title, updatedAt: DateTime.now()));
    await reload();
  }

  Future<void> deleteAll() async {
    final store = ref.read(chatStoreProvider);
    await store.deleteAll();
    if (ref.mounted) state = const AsyncData([]);
  }
}

final chatListProvider =
    AsyncNotifierProvider<ChatListNotifier, List<AskChatHeader>>(
      ChatListNotifier.new,
    );

/// How many chats are saved and how much room they take (for the settings).
final chatStorageProvider = FutureProvider<({int count, int bytes})>((
  ref,
) async {
  // Follows the list: a chat saved or deleted makes it again.
  await ref.watch(chatListProvider.future);
  final store = ref.watch(chatStoreProvider);
  return (count: await store.chatCount(), bytes: await store.totalSizeBytes());
});

/// Finds any existing chats that reference [ayah].
final chatsForAyahProvider =
    FutureProvider.family<List<AskChatHeader>, AyahRef>((ref, ayah) async {
      final all = await ref.watch(chatListProvider.future);
      return [
        for (final c in all)
          if (c.anchors.contains(ayah)) c,
      ];
    });

/// Active state of a chat thread: the loaded chat, whether streaming, error.
class ChatDetailState {
  const ChatDetailState({
    required this.chat,
    this.isGenerating = false,
    this.error,
    this.errorKind,
  });

  final AskChat chat;
  final bool isGenerating;

  /// What went wrong with the last answer (the provider's own words); null when
  /// nothing did.
  final String? error;

  /// The kind of the provider's error, when it was one (a missing key is shown
  /// with a way to the settings).
  final AiErrorKind? errorKind;

  ChatDetailState copyWith({
    AskChat? chat,
    bool? isGenerating,
    String? error,
    AiErrorKind? errorKind,
  }) {
    return ChatDetailState(
      chat: chat ?? this.chat,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
      errorKind: errorKind,
    );
  }
}

/// Controller for an individual chat session.
///
/// A chat is made in memory and written to the store with its first message: a
/// chat that was opened and left is not kept (the list would fill with empty
/// ones).
class ChatDetailNotifier extends AsyncNotifier<ChatDetailState?> {
  ChatDetailNotifier(this.arg);

  final String arg;
  StreamSubscription<String>? _streamSub;

  // Ends the wait of the answer being made: completed by the stream ending, by
  // an error, or by a stop.
  Completer<void>? _streamEnd;
  bool _stopRequested = false;
  bool _deleted = false;

  /// How many of the last messages go to the model (the pinned ayah goes with
  /// the first of them).
  static const int historyWindow = 6;

  @override
  Future<ChatDetailState?> build() async {
    ref.onDispose(() {
      unawaited(_streamSub?.cancel());
      _streamSub = null;
    });
    final store = ref.watch(chatStoreProvider);
    final chat = await store.load(arg);
    if (chat == null) return null;
    return ChatDetailState(chat: chat);
  }

  /// Keeps [chat] in the store, once it has a message.
  Future<void> _persist(AskChat chat) async {
    if (_deleted || chat.messages.isEmpty) return;
    await ref.read(chatStoreProvider).save(chat);
    unawaited(ref.read(chatListProvider.notifier).reload());
  }

  /// A new chat, in memory until its first message.
  Future<void> createChat(AskChat initial) async {
    // Whatever the first build found (nothing) must not come after this.
    await future;
    if (!ref.mounted) return;
    state = AsyncData(ChatDetailState(chat: initial));
  }

  Future<void> rename(String newTitle) async {
    final current = state.value?.chat;
    if (current == null) return;
    final updated = current.copyWith(
      title: newTitle.trim(),
      updatedAt: DateTime.now(),
    );
    await _persist(updated);
    state = AsyncData(state.value!.copyWith(chat: updated));
  }

  Future<void> attachContext(AskContext ctx) async {
    final current = state.value?.chat;
    if (current == null) return;
    if (current.pinned.length >= 3) return; // Capped at 3 attachments

    final updatedPinned = [...current.pinned, ctx];
    final updatedAnchors = {...current.anchors, ctx.ayah}.toList();
    final updated = current.copyWith(
      pinned: updatedPinned,
      anchors: updatedAnchors,
      updatedAt: DateTime.now(),
    );
    await _persist(updated);
    state = AsyncData(state.value!.copyWith(chat: updated));
  }

  /// Stops the answer that is being written. What was written so far is kept,
  /// marked as interrupted.
  void stopStreaming() {
    final s = state.value;
    if (s == null || !s.isGenerating) return;
    _stopRequested = true;
    unawaited(_streamSub?.cancel());
    _streamSub = null;
    final end = _streamEnd;
    if (end != null && !end.isCompleted) end.complete();
  }

  /// Deletes this chat (stopping an answer that is being written, so that it
  /// does not write the chat again).
  Future<void> deleteChat() async {
    _deleted = true;
    stopStreaming();
    await ref.read(chatStoreProvider).delete(arg);
    unawaited(ref.read(chatListProvider.notifier).reload());
  }

  /// [text] as a message of the reader. [label] names it in the title of a new
  /// chat when [text] is a long instruction (a preset); null: the text itself.
  Future<void> sendMessage(
    String text, {
    String? label,
    AskContext? attachContext,
  }) async {
    final s = state.value;
    final clean = text.trim();
    if (s == null || s.isGenerating || clean.isEmpty) return;
    final chat = s.chat;

    // Attach context if provided
    var pinned = chat.pinned;
    var anchors = chat.anchors;
    if (attachContext != null && pinned.length < 3) {
      pinned = [...pinned, attachContext];
      anchors = {...anchors, attachContext.ayah}.toList();
    }

    final userMsg = AskMessage(
      id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
      role: AiRole.user,
      text: clean,
      createdAt: DateTime.now(),
      context: attachContext,
    );

    // The first message names the chat: what was asked, and the ayah.
    var title = chat.title;
    if (chat.messages.isEmpty) {
      final named = (label ?? clean).trim();
      title = named.length > 40 ? '${named.substring(0, 40)}…' : named;
      if (anchors.isNotEmpty) title = '$title · ${anchors.first.key}';
    }

    final updatedChat = chat.copyWith(
      title: title,
      pinned: pinned,
      anchors: anchors,
      messages: [...chat.messages, userMsg],
      updatedAt: DateTime.now(),
    );

    await _persist(updatedChat);
    if (!ref.mounted) return;
    state = AsyncData(ChatDetailState(chat: updatedChat, isGenerating: true));

    // Now call AI
    await _generateAssistantResponse(updatedChat);
  }

  /// Tries the last question again: after a failure (the question has no
  /// answer, or the answer stopped halfway), or to write the last answer anew.
  Future<void> retry() async {
    final s = state.value;
    if (s == null || s.isGenerating || s.chat.messages.isEmpty) return;
    final chat = s.chat;
    final messages = chat.messages.last.role == AiRole.assistant
        ? chat.messages.sublist(0, chat.messages.length - 1)
        : chat.messages;
    if (messages.isEmpty || messages.last.role != AiRole.user) return;
    final updatedChat = chat.copyWith(messages: messages);
    state = AsyncData(ChatDetailState(chat: updatedChat, isGenerating: true));
    await _generateAssistantResponse(updatedChat);
  }

  Future<void> deleteMessage(String messageId) async {
    final s = state.value;
    if (s == null) return;
    final messages = s.chat.messages.where((m) => m.id != messageId).toList();
    final updatedChat = s.chat.copyWith(messages: messages);
    await _persist(updatedChat);
    state = AsyncData(s.copyWith(chat: updatedChat));
  }

  /// What goes to the model: the last [historyWindow] messages, starting with a
  /// message of the reader (a model must not be handed an answer first), the
  /// pinned ayahs written into that first message.
  static List<AiMessage> historyFor(AskChat chat) {
    var window = chat.messages.length > historyWindow
        ? chat.messages.sublist(chat.messages.length - historyWindow)
        : chat.messages;
    final firstUser = window.indexWhere((m) => m.role == AiRole.user);
    window = firstUser < 0 ? const [] : window.sublist(firstUser);

    final contextBlock = AskPrompts.formatContextBlock(chat.pinned);
    return [
      for (var i = 0; i < window.length; i++)
        AiMessage(
          window[i].role,
          i == 0 && contextBlock.isNotEmpty
              ? '$contextBlock\n\n${window[i].text}'
              : window[i].text,
        ),
    ];
  }

  Future<void> _generateAssistantResponse(AskChat currentChat) async {
    final settings = ref.read(askSettingsProvider);
    final providerId = settings.provider;
    final model = settings.models[providerId];
    final client = ref.read(
      aiChatClientProvider((providerId: providerId, model: model)),
    );

    final system = AskPrompts.buildSystemPrompt(
      language: AskPrompts.languageName(settings.answerLanguage),
      hasContext: currentChat.pinned.isNotEmpty,
      shortLength: settings.answerLength == 'short',
    );
    final aiMessages = historyFor(currentChat);

    final assistantMsgId = 'msg_${DateTime.now().microsecondsSinceEpoch}_ai';
    var accumulated = '';
    _stopRequested = false;

    AskChat withAnswer({required bool interrupted}) => currentChat.copyWith(
      messages: [
        ...currentChat.messages,
        AskMessage(
          id: assistantMsgId,
          role: AiRole.assistant,
          text: accumulated,
          createdAt: DateTime.now(),
          interrupted: interrupted,
        ),
      ],
      updatedAt: DateTime.now(),
      providerId: providerId,
      model: model ?? '',
    );

    try {
      final stream = client.streamText(system: system, messages: aiMessages);
      final end = Completer<void>();
      _streamEnd = end;

      _streamSub = stream.listen(
        (delta) {
          accumulated += delta;
          if (!ref.mounted) return;
          state = AsyncData(
            ChatDetailState(
              chat: withAnswer(interrupted: false),
              isGenerating: true,
            ),
          );
        },
        onError: (Object error, StackTrace stack) {
          if (!end.isCompleted) end.completeError(error, stack);
        },
        onDone: () {
          if (!end.isCompleted) end.complete();
        },
        cancelOnError: true,
      );

      await end.future;
      if (!ref.mounted) return;

      if (_stopRequested) {
        // The reader stopped it: what is written is kept, as interrupted.
        if (accumulated.trim().isEmpty) {
          state = AsyncData(
            ChatDetailState(chat: currentChat, isGenerating: false),
          );
        } else {
          final saved = withAnswer(interrupted: true);
          await _persist(saved);
          state = AsyncData(ChatDetailState(chat: saved));
        }
        return;
      }

      if (accumulated.trim().isEmpty) {
        throw const AiProviderException(
          AiErrorKind.emptyResponse,
          'The model sent no answer. Try again, or ask in other words.',
        );
      }

      final saved = withAnswer(interrupted: false);
      await _persist(saved);
      state = AsyncData(ChatDetailState(chat: saved));
    } catch (e) {
      if (!ref.mounted) return;
      final kind = e is AiProviderException ? e.kind : null;
      final message = e is AiProviderException ? e.message : e.toString();
      // Text that came before the failure is kept, marked as interrupted.
      if (accumulated.trim().isNotEmpty) {
        final saved = withAnswer(interrupted: true);
        await _persist(saved);
        state = AsyncData(
          ChatDetailState(chat: saved, error: message, errorKind: kind),
        );
      } else {
        state = AsyncData(
          ChatDetailState(chat: currentChat, error: message, errorKind: kind),
        );
      }
    } finally {
      unawaited(_streamSub?.cancel());
      _streamSub = null;
      _streamEnd = null;
    }
  }
}

final chatDetailProvider =
    AsyncNotifierProvider.family<ChatDetailNotifier, ChatDetailState?, String>(
      ChatDetailNotifier.new,
    );
