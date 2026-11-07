import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:personaltskmng/ask/data/chat_store.dart';
import 'package:personaltskmng/ask/models/ask_chat.dart';

/// File-based [ChatStore] keeping chats in a dedicated `ask/` folder.
///
/// Features:
/// - One file per chat: `chat_<id>.json`
/// - Lightweight index: `index.json`
/// - Atomic writes using temp files and flush before rename
/// - Corrupt files are quarantined as `.bad-<timestamp>`
/// - Hard limit of 200 chats (drops oldest)
final class FileChatStore implements ChatStore {
  FileChatStore(this.directory, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  static const String indexFileName = 'index.json';
  static const int maxChats = 200;

  final Directory directory;
  final DateTime Function() _clock;

  Future<void> _tail = Future<void>.value();

  String _path(String name) =>
      '${directory.path}${Platform.pathSeparator}$name';

  File _file(String name) => File(_path(name));

  String _chatFileName(String id) => 'chat_$id.json';

  Future<void> _ensureDir() async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<void> _writeAtomic(String name, String content) async {
    await _ensureDir();
    final tmp = _file('$name.tmp');
    final target = _file(name);
    final sink = tmp.openWrite();
    sink.write(content);
    await sink.flush();
    await sink.close();
    await tmp.rename(target.path);
  }

  Future<void> _quarantine(File file) async {
    try {
      if (await file.exists()) {
        final stamp = _clock().toIso8601String().replaceAll(':', '-');
        await file.rename('${file.path}.bad-$stamp');
      }
    } catch (_) {}
  }

  @override
  Future<List<AskChatHeader>> list() => _enqueue(() async {
        await _ensureDir();
        final file = _file(indexFileName);
        if (!await file.exists()) return [];
        try {
          final content = await file.readAsString();
          final decoded = jsonDecode(content);
          if (decoded is List) {
            final headers = <AskChatHeader>[];
            for (final item in decoded) {
              if (item is Map<String, dynamic>) {
                headers.add(AskChatHeader.fromJson(item));
              }
            }
            headers.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
            return headers;
          }
        } on FormatException {
          await _quarantine(file);
        } catch (_) {}
        return [];
      });

  @override
  Future<AskChat?> load(String id) => _enqueue(() async {
        await _ensureDir();
        final file = _file(_chatFileName(id));
        if (!await file.exists()) return null;
        try {
          final content = await file.readAsString();
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            return AskChat.fromJson(decoded);
          }
        } on FormatException {
          await _quarantine(file);
        } catch (_) {}
        return null;
      });

  @override
  Future<void> save(AskChat chat) => _enqueue(() async {
        await _ensureDir();

        // 1. Write chat file
        final chatJson = jsonEncode(chat.toJson());
        await _writeAtomic(_chatFileName(chat.id), chatJson);

        // 2. Update index
        final headers = (await _readIndexUnqueued())
            .where((h) => h.id != chat.id)
            .toList();
        headers.insert(0, chat.toHeader());

        // Trim to maxChats
        while (headers.length > maxChats) {
          final removed = headers.removeLast();
          final oldFile = _file(_chatFileName(removed.id));
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        }

        final indexJson = jsonEncode([for (final h in headers) h.toJson()]);
        await _writeAtomic(indexFileName, indexJson);
      });

  Future<List<AskChatHeader>> _readIndexUnqueued() async {
    final file = _file(indexFileName);
    if (!await file.exists()) return [];
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is List) {
        return [
          for (final item in decoded)
            if (item is Map<String, dynamic>) AskChatHeader.fromJson(item),
        ];
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<void> delete(String id) => _enqueue(() async {
        await _ensureDir();
        final chatFile = _file(_chatFileName(id));
        if (await chatFile.exists()) {
          await chatFile.delete();
        }

        final headers =
            (await _readIndexUnqueued()).where((h) => h.id != id).toList();
        final indexJson = jsonEncode([for (final h in headers) h.toJson()]);
        await _writeAtomic(indexFileName, indexJson);
      });

  @override
  Future<void> deleteAll() => _enqueue(() async {
        if (!await directory.exists()) return;
        try {
          final entities = await directory.list().toList();
          for (final e in entities) {
            if (e is File) {
              await e.delete();
            }
          }
        } catch (_) {}
      });

  @override
  Future<int> chatCount() => _enqueue(() async {
        final headers = await _readIndexUnqueued();
        return headers.length;
      });

  @override
  Future<int> totalSizeBytes() => _enqueue(() async {
        if (!await directory.exists()) return 0;
        var bytes = 0;
        try {
          final entities = await directory.list().toList();
          for (final e in entities) {
            if (e is File) {
              bytes += await e.length();
            }
          }
        } catch (_) {}
        return bytes;
      });
}

