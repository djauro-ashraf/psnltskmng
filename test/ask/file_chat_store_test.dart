import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ask/data/file_chat_store.dart';
import 'package:personaltskmng/ask/models/ask_chat.dart';
import 'package:personaltskmng/ask/models/ask_context.dart';
import 'package:personaltskmng/ask/models/ask_message.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';

void main() {
  late Directory tempDir;
  late FileChatStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ask_test_');
    store = FileChatStore(tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves and loads a chat with atomic write and index update', () async {
    expect(await store.list(), isEmpty);

    final chat = AskChat(
      id: 'chat_1',
      title: 'Explain simply · 2:255',
      createdAt: DateTime(2026, 11, 1),
      updatedAt: DateTime(2026, 11, 1, 10, 0),
      anchors: const [AyahRef(2, 255)],
      pinned: const [
        AskContext(
          ayah: AyahRef(2, 255),
          arabic: 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ',
          translation: 'Allah - there is no deity except Him',
        ),
      ],
      messages: [
        AskMessage(
          id: 'm1',
          role: AiRole.user,
          text: 'Explain simply',
          createdAt: DateTime(2026, 11, 1, 10, 0),
        ),
        AskMessage(
          id: 'm2',
          role: AiRole.assistant,
          text: 'Ayat al-Kursi tells us about the majesty of Allah.',
          createdAt: DateTime(2026, 11, 1, 10, 1),
        ),
      ],
    );

    await store.save(chat);

    // List headers
    final list = await store.list();
    expect(list.length, 1);
    expect(list.first.id, 'chat_1');
    expect(list.first.title, 'Explain simply · 2:255');
    expect(list.first.anchors, [const AyahRef(2, 255)]);
    expect(list.first.snippet, contains('Ayat al-Kursi'));

    // Load full chat
    final loaded = await store.load('chat_1');
    expect(loaded, isNotNull);
    expect(loaded!.title, 'Explain simply · 2:255');
    expect(loaded.pinned.length, 1);
    expect(loaded.pinned.first.arabic, 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ');
    expect(loaded.messages.length, 2);
    expect(loaded.messages.last.role, AiRole.assistant);

    // Count and size
    expect(await store.chatCount(), 1);
    expect(await store.totalSizeBytes(), greaterThan(0));
  });

  test('deletes a chat and updates index', () async {
    final chat1 = AskChat(
      id: 'c1',
      title: 'Chat 1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final chat2 = AskChat(
      id: 'c2',
      title: 'Chat 2',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await store.save(chat1);
    await store.save(chat2);
    expect(await store.chatCount(), 2);

    await store.delete('c1');
    expect(await store.chatCount(), 1);
    expect(await store.load('c1'), isNull);
    expect(await store.load('c2'), isNotNull);
  });

  test('quarantines corrupt chat file without throwing', () async {
    final chat = AskChat(
      id: 'corrupt_me',
      title: 'Corrupt test',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await store.save(chat);

    // Corrupt the json file
    final file = File('${tempDir.path}${Platform.pathSeparator}chat_corrupt_me.json');
    await file.writeAsString('{{{ invalid json content');

    final loaded = await store.load('corrupt_me');
    expect(loaded, isNull);

    // Verify it was quarantined
    final entities = tempDir.listSync();
    expect(entities.any((e) => e.path.contains('.bad-')), isTrue);
  });
}

