import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/ai/ai_chat_provider.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/gemini_chat.dart';
import 'package:personaltskmng/ai/groq_chat.dart';
import 'package:personaltskmng/ask/data/chat_store.dart';
import 'package:personaltskmng/ask/data/in_memory_chat_store.dart';
import 'package:personaltskmng/ask/models/ask_chat.dart';
import 'package:personaltskmng/ask/models/ask_context.dart';
import 'package:personaltskmng/ask/models/ask_message.dart';
import 'package:personaltskmng/ask/models/ask_settings.dart';
import 'package:personaltskmng/ask/prompts/ask_prompts.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';

/// Active [ChatStore]. Overridden in `app/dependencies.dart` with [FileChatStore].
final chatStoreProvider = Provider<ChatStore>(
  (ref) => InMemoryChatStore(),
);

/// In-memory storage for Ask AI settings fallback (or updated from prefs).
class AskSettingsNotifier extends Notifier<AskSettings> {
  @override
  AskSettings build() => const AskSettings();

  void update(AskSettings newSettings) {
    state = newSettings;
  }

  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }

  void setProvider(String provider) {
    state = state.copyWith(provider: provider);
  }

  void setModel(String providerId, String model) {
    final updated = Map<String, String>.from(state.models);
    updated[providerId] = model;
    state = state.copyWith(models: updated);
  }

  void setLanguage(String lang) {
    state = state.copyWith(answerLanguage: lang);
  }

  void setLength(String length) {
    state = state.copyWith(answerLength: length);
  }
}

final askSettingsProvider =
    NotifierProvider<AskSettingsNotifier, AskSettings>(
  AskSettingsNotifier.new,
);

/// Whether Ask AI has an active API key for the chosen provider.
final askHasKeyProvider = FutureProvider<bool>((ref) async {
  final settings = ref.watch(askSettingsProvider);
  final keys = ref.watch(aiKeyStoreProvider);
  final key = await keys.read(settings.provider);
  return key != null && key.trim().isNotEmpty;
});

/// Whether Ask AI is ready to be used (enabled AND has key).
final askAvailableProvider = Provider<bool>((ref) {
  final enabled = ref.watch(askSettingsProvider.select((s) => s.enabled));
  final hasKey = ref.watch(askHasKeyProvider).value ?? false;
  return enabled && hasKey;
});

/// Factory returning [AiChatProvider] for a given provider id and model.
final aiChatClientProvider = Provider.family<AiChatProvider, ({String providerId, String? model})>(
  (ref, args) {
    final keys = ref.watch(aiKeyStoreProvider);
    final providerId = args.providerId;
    final model = args.model;
    if (providerId == 'groq') {
      return GroqChat(
        keys: keys,
        model: (model != null && model.isNotEmpty) ? model : GroqChat.defaultModel,
      );
    }
    return GeminiChat(
      keys: keys,
      model: (model != null && model.isNotEmpty) ? model : GeminiChat.defaultModel,
    );
  },
);

/// Manages the list of all Ask AI chats.
class ChatListNotifier extends AsyncNotifier<List<AskChatHeader>> {
  @override
  Future<List<AskChatHeader>> build() async {
    final store = ref.watch(chatStoreProvider);
    return store.list();
  }

  Future<void> reload() async {
    final store = ref.read(chatStoreProvider);
    state = AsyncData(await store.list());
  }

  Future<void> delete(String id) async {
    final store = ref.read(chatStoreProvider);
    await store.delete(id);
    await reload();
  }

  Future<void> deleteAll() async {
    final store = ref.read(chatStoreProvider);
    await store.deleteAll();
    state = const AsyncData([]);
  }
}

final chatListProvider =
    AsyncNotifierProvider<ChatListNotifier, List<AskChatHeader>>(
  ChatListNotifier.new,
);

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
  });

  final AskChat chat;
  final bool isGenerating;
  final String? error;

  ChatDetailState copyWith({
    AskChat? chat,
    bool? isGenerating,
    String? error,
  }) {
    return ChatDetailState(
      chat: chat ?? this.chat,
      isGenerating: isGenerating ?? this.isGenerating,
      error: error,
    );
  }
}

/// Controller for an individual chat session.
class ChatDetailNotifier extends AsyncNotifier<ChatDetailState?> {
  ChatDetailNotifier(this.arg);

  final String arg;
  StreamSubscription<String>? _streamSub;

  @override
  Future<ChatDetailState?> build() async {
    final store = ref.watch(chatStoreProvider);
    final chat = await store.load(arg);
    if (chat == null) return null;
    return ChatDetailState(chat: chat);
  }

  Future<void> createChat(AskChat initial) async {
    final store = ref.read(chatStoreProvider);
    await store.save(initial);
    ref.read(chatListProvider.notifier).reload();
    state = AsyncData(ChatDetailState(chat: initial));
  }

  Future<void> rename(String newTitle) async {
    final current = state.value?.chat;
    if (current == null) return;
    final updated = current.copyWith(
      title: newTitle.trim(),
      updatedAt: DateTime.now(),
    );
    final store = ref.read(chatStoreProvider);
    await store.save(updated);
    ref.read(chatListProvider.notifier).reload();
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
    final store = ref.read(chatStoreProvider);
    await store.save(updated);
    ref.read(chatListProvider.notifier).reload();
    state = AsyncData(state.value!.copyWith(chat: updated));
  }

  void stopStreaming() {
    _streamSub?.cancel();
    _streamSub = null;
    final s = state.value;
    if (s != null && s.isGenerating) {
      state = AsyncData(s.copyWith(isGenerating: false));
    }
  }

  Future<void> sendMessage(String text, {AskContext? attachContext}) async {
    final s = state.value;
    if (s == null || s.isGenerating) return;
    final chat = s.chat;

    // Attach context if provided
    var pinned = chat.pinned;
    var anchors = chat.anchors;
    if (attachContext != null && pinned.length < 3) {
      pinned = [...pinned, attachContext];
      anchors = {...anchors, attachContext.ayah}.toList();
    }

    final userMsg = AskMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      role: AiRole.user,
      text: text.trim(),
      createdAt: DateTime.now(),
      context: attachContext,
    );

    // Dynamic title from first message if untitled
    String title = chat.title;
    if (chat.messages.isEmpty || title == 'New Chat' || title == 'Untitled') {
      final t = text.trim();
      title = t.length > 40 ? '${t.substring(0, 40)}…' : t;
      if (attachContext != null) {
        title = '$title · ${attachContext.ayah.key}';
      }
    }

    final updatedMessages = [...chat.messages, userMsg];
    final updatedChat = chat.copyWith(
      title: title,
      pinned: pinned,
      anchors: anchors,
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );

    final store = ref.read(chatStoreProvider);
    await store.save(updatedChat);
    ref.read(chatListProvider.notifier).reload();

    state = AsyncData(ChatDetailState(chat: updatedChat, isGenerating: true));

    // Now call AI
    await _generateAssistantResponse(updatedChat);
  }

  Future<void> regenerateLast() async {
    final s = state.value;
    if (s == null || s.isGenerating || s.chat.messages.isEmpty) return;
    final chat = s.chat;
    if (chat.messages.last.role != AiRole.assistant) return;

    // Drop last assistant message
    final messages = chat.messages.sublist(0, chat.messages.length - 1);
    final updatedChat = chat.copyWith(messages: messages);
    state = AsyncData(ChatDetailState(chat: updatedChat, isGenerating: true));
    await _generateAssistantResponse(updatedChat);
  }

  Future<void> deleteMessage(String messageId) async {
    final s = state.value;
    if (s == null) return;
    final messages = s.chat.messages.where((m) => m.id != messageId).toList();
    final updatedChat = s.chat.copyWith(messages: messages);
    final store = ref.read(chatStoreProvider);
    await store.save(updatedChat);
    ref.read(chatListProvider.notifier).reload();
    state = AsyncData(s.copyWith(chat: updatedChat));
  }

  Future<void> _generateAssistantResponse(AskChat currentChat) async {
    final settings = ref.read(askSettingsProvider);
    final providerId = settings.provider;
    final model = settings.models[providerId];
    final client = ref.read(aiChatClientProvider((providerId: providerId, model: model)));

    final system = AskPrompts.buildSystemPrompt(
      language: settings.answerLanguage,
      hasContext: currentChat.pinned.isNotEmpty,
      shortLength: settings.answerLength == 'short',
    );

    // Sliding window of last 6 turns
    final history = currentChat.messages.length > 6
        ? currentChat.messages.sublist(currentChat.messages.length - 6)
        : currentChat.messages;

    final aiMessages = <AiMessage>[];

    // Prepend pinned grounding context to the first turn
    final contextBlock = AskPrompts.formatContextBlock(currentChat.pinned);
    for (var i = 0; i < history.length; i++) {
      final m = history[i];
      if (i == 0 && contextBlock.isNotEmpty) {
        aiMessages.add(AiMessage(m.role, '$contextBlock\n\n${m.text}'));
      } else {
        aiMessages.add(AiMessage(m.role, m.text));
      }
    }

    final assistantMsgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_ai';
    var accumulated = '';

    try {
      final stream = client.streamText(system: system, messages: aiMessages);
      final completer = Completer<void>();

      _streamSub = stream.listen(
        (delta) {
          accumulated += delta;
          final currentMsgs = [
            ...currentChat.messages,
            AskMessage(
              id: assistantMsgId,
              role: AiRole.assistant,
              text: accumulated,
              createdAt: DateTime.now(),
            ),
          ];
          state = AsyncData(ChatDetailState(
            chat: currentChat.copyWith(messages: currentMsgs),
            isGenerating: true,
          ));
        },
        onError: (Object error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;

      // Completed successfully
      final finalMsgs = [
        ...currentChat.messages,
        AskMessage(
          id: assistantMsgId,
          role: AiRole.assistant,
          text: accumulated,
          createdAt: DateTime.now(),
        ),
      ];
      final savedChat = currentChat.copyWith(
        messages: finalMsgs,
        updatedAt: DateTime.now(),
        providerId: providerId,
        model: model ?? '',
      );

      final store = ref.read(chatStoreProvider);
      await store.save(savedChat);
      ref.read(chatListProvider.notifier).reload();

      state = AsyncData(ChatDetailState(
        chat: savedChat,
        isGenerating: false,
      ));
    } catch (e) {
      final errorMsg = e is AiProviderException ? e.message : e.toString();
      // If we got partial text before failing, keep it marked interrupted
      if (accumulated.isNotEmpty) {
        final finalMsgs = [
          ...currentChat.messages,
          AskMessage(
            id: assistantMsgId,
            role: AiRole.assistant,
            text: accumulated,
            createdAt: DateTime.now(),
            interrupted: true,
          ),
        ];
        final savedChat = currentChat.copyWith(messages: finalMsgs);
        final store = ref.read(chatStoreProvider);
        await store.save(savedChat);
        ref.read(chatListProvider.notifier).reload();
        state = AsyncData(ChatDetailState(
          chat: savedChat,
          isGenerating: false,
          error: errorMsg,
        ));
      } else {
        state = AsyncData(ChatDetailState(
          chat: currentChat,
          isGenerating: false,
          error: errorMsg,
        ));
      }
    } finally {
      _streamSub?.cancel();
      _streamSub = null;
    }
  }
}

final chatDetailProvider =
    AsyncNotifierProvider.family<ChatDetailNotifier, ChatDetailState?, String>(
  ChatDetailNotifier.new,
);
