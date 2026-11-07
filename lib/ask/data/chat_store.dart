import 'package:personaltskmng/ask/models/ask_chat.dart';

/// Storage interface for Ask AI chats.
abstract interface class ChatStore {
  /// Returns lightweight headers for all saved chats, newest first.
  Future<List<AskChatHeader>> list();

  /// Loads full chat by id. Returns null if not found.
  Future<AskChat?> load(String id);

  /// Saves a chat (or creates it).
  Future<void> save(AskChat chat);

  /// Deletes a chat by id.
  Future<void> delete(String id);

  /// Deletes all saved chats.
  Future<void> deleteAll();

  /// Total number of chats.
  Future<int> chatCount();

  /// Total size in bytes of chat storage.
  Future<int> totalSizeBytes();
}

