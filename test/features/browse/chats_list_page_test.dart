import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ask/controller/ask_providers.dart';
import 'package:personaltskmng/ask/data/in_memory_chat_store.dart';
import 'package:personaltskmng/ask/models/ask_chat.dart';
import 'package:personaltskmng/ask/models/ask_message.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/presentation/pages/chats_list_page.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';

AskChat chat(String id, String title, {DateTime? updated, String? answer}) {
  final when = updated ?? DateTime.now();
  return AskChat(
    id: id,
    title: title,
    createdAt: when,
    updatedAt: when,
    anchors: const [AyahRef(2, 255)],
    messages: [
      AskMessage(
        id: '$id-1',
        role: AiRole.assistant,
        text: answer ?? 'An answer of $title',
        createdAt: when,
      ),
    ],
  );
}

Future<void> openList(WidgetTester tester, InMemoryChatStore store) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [chatStoreProvider.overrideWithValue(store)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChatsListPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no chat: an invitation to ask', (tester) async {
    await openList(tester, InMemoryChatStore());
    expect(find.text('No chats yet'), findsOneWidget);
    expect(find.text('Ask about an ayah'), findsOneWidget);
  });

  testWidgets('chats are listed, with their day, and can be searched', (
    tester,
  ) async {
    final store = InMemoryChatStore([
      chat('a', 'Ayat al-Kursi', answer: 'About the throne verse'),
      chat(
        'b',
        'Patience',
        updated: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
    await openList(tester, store);

    expect(find.text('Ayat al-Kursi'), findsOneWidget);
    expect(find.text('Patience'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'throne');
    await tester.pumpAndSettle();
    expect(find.text('Ayat al-Kursi'), findsOneWidget);
    expect(find.text('Patience'), findsNothing);

    // Nothing fits: not "No chats yet", the chats are there.
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No chat matches your search'), findsOneWidget);
    expect(find.text('No chats yet'), findsNothing);
  });

  testWidgets('a swiped chat is deleted and Undo puts it back', (
    tester,
  ) async {
    final store = InMemoryChatStore([chat('a', 'Ayat al-Kursi')]);
    await openList(tester, store);

    await tester.drag(find.text('Ayat al-Kursi'), const Offset(-700, 0));
    await tester.pumpAndSettle();

    expect(await store.load('a'), isNull);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.text('No chats yet'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(await store.load('a'), isNotNull);
    expect(find.text('Ayat al-Kursi'), findsOneWidget);
  });

  testWidgets('the menu of a chat renames it', (tester) async {
    final store = InMemoryChatStore([chat('a', 'Ayat al-Kursi')]);
    await openList(tester, store);

    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'The throne verse');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((await store.load('a'))?.title, 'The throne verse');
    expect(find.text('The throne verse'), findsOneWidget);
  });
}
