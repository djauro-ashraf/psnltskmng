// ignore_for_file: depend_on_referenced_packages

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/notes/data/file_note_store.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/preferences_note_store.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

NoteBook _bookWithTwoNotes() {
  var book = const NoteBook();
  (book, _) = book.add(page: 12, s: 2, ch: 2, text: 'one', today: const Day(5));
  (book, _) = book.add(page: 106, s: 5, ch: 13, text: 'two', today: const Day(5));
  return book;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileNoteStore', () {
    late Directory tmp;
    late FileNoteStore store;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('qrm_notes_');
      store = FileNoteStore(tmp, clock: () => DateTime.utc(2026, 10, 10));
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    File file(String name) => File('${tmp.path}${Platform.pathSeparator}$name');

    test('no file is an empty book', () async {
      final result = await store.load();
      expect(result.book.notes, isEmpty);
      expect(result.problem, isNull);
    });

    test('saves into notes.json and reads it back; no .tmp is left', () async {
      await store.save(_bookWithTwoNotes());
      expect(file('notes.json').existsSync(), isTrue);
      expect(file('notes.json.tmp').existsSync(), isFalse);

      final result = await FileNoteStore(tmp).load();
      expect(result.book.notes.map((n) => n.text), ['one', 'two']);
      expect(result.book.nextNumber, 3);
    });

    test('the notes file is its own: no other file is created', () async {
      await store.save(_bookWithTwoNotes());
      expect(tmp.listSync().map((e) => e.uri.pathSegments.last), ['notes.json']);
    });

    test('saving again replaces the file', () async {
      await store.save(_bookWithTwoNotes());
      await store.save(const NoteBook());
      final result = await store.load();
      expect(result.book.notes, isEmpty);
    });

    test('a corrupt file is moved aside, never overwritten', () async {
      file('notes.json').writeAsStringSync('{broken');
      final result = await store.load();
      expect(result.book.notes, isEmpty);
      expect(result.problem, isNotNull);
      expect(result.quarantinedAs, startsWith('notes.json.bad-'));
      expect(file(result.quarantinedAs!).readAsStringSync(), '{broken');
      expect(file('notes.json').existsSync(), isFalse);
    });

    test('a stale .tmp is never read', () async {
      await store.save(_bookWithTwoNotes());
      file('notes.json.tmp').writeAsStringSync('{half written');
      final result = await store.load();
      expect(result.book.notes.length, 2);
      expect(result.problem, isNull);
    });

    test('queued saves keep their order', () async {
      var book = const NoteBook();
      final saves = <Future<void>>[];
      for (var i = 1; i <= 5; i++) {
        (book, _) = book.add(
          page: 12,
          s: 2,
          ch: 2,
          text: 'note $i',
          today: const Day(5),
        );
        saves.add(store.save(book));
      }
      await Future.wait(saves);
      final back = NoteCodec.fromText(file('notes.json').readAsStringSync());
      expect(back.notes.length, 5);
    });
  });

  group('PreferencesNoteStore', () {
    late SharedPreferencesWithCache prefs;
    late PreferencesNoteStore store;

    setUp(() async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      prefs = await SharedPreferencesWithCache.create(
        cacheOptions: const SharedPreferencesWithCacheOptions(),
      );
      store = PreferencesNoteStore(
        prefs,
        clock: () => DateTime.utc(2026, 10, 10),
      );
    });

    test('empty, then save and reload', () async {
      expect((await store.load()).book.notes, isEmpty);
      await store.save(_bookWithTwoNotes());
      expect((await store.load()).book.notes.length, 2);
    });

    test('keeps its own key, apart from the planning data', () async {
      await store.save(_bookWithTwoNotes());
      expect(prefs.keys, {PreferencesNoteStore.key});
    });

    test('corrupt text is moved aside under another key', () async {
      await prefs.setString(PreferencesNoteStore.key, 'not json');
      final result = await store.load();
      expect(result.book.notes, isEmpty);
      expect(result.problem, isNotNull);
      expect(prefs.getString(PreferencesNoteStore.key), isNull);
      expect(prefs.getString(result.quarantinedAs!), 'not json');
    });
  });
}
