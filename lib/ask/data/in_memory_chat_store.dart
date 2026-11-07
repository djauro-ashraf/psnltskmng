import 'dart:convert';

import 'package:personaltskmng/ask/data/chat_store.dart';
import 'package:personaltskmng/ask/models/ask_chat.dart';

/// Test implementation of [ChatStore] in memory.
final class InMemoryChatStore implements ChatStore {
  InMemoryChatStore([List<AskChat>? initial]) {
    if (initial != null) {
      for (final c in initial) {
        _chats[c.id] = c;
      }
    }
  }

  final Map<String, AskChat> _chats = {};

  @override
  Future<List<AskChatHeader>> list() async {
    final list = [for (final c in _chats.values) c.toHeader()];
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<AskChat?> load(String id) async => _chats[id];

  @override
  Future<void> save(AskChat chat) async {
    _chats[chat.id] = chat;
  }

  @override
  Future<void> delete(String id) async {
    _chats.remove(id);
  }

  @override
  Future<void> deleteAll() async {
    _chats.clear();
  }

  @override
  Future<int> chatCount() async => _chats.length;

  @override
  Future<int> totalSizeBytes() async {
    var total = 0;
    for (final c in _chats.values) {
      total += utf8.encode(jsonEncode(c.toJson())).length;
    }
    return total;
  }
}

