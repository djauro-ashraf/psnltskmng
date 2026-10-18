import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';

NoteBook _sampleBook() => const NoteBook(
  notes: [
    Note(
      id: 'n1',
      page: 106,
      s: 5,
      ch: 13,
      text: 'the verb forms',
      createdOn: Day(20000),
      counted: [Day(20001), Day(20003)],
      pending: [Day(20004)],
    ),
    Note(
      id: 'n2',
      page: 12,
      s: 2,
      ch: 2,
      text: 'a résumé: "quotes" and\nnewline',
      createdOn: Day(20000),
      counted: [Day(20001), Day(20002), Day(20003), Day(20004), Day(20005)],
      resolvedOn: Day(20005),
    ),
  ],
  nextNumber: 3,
);

String _withNote(Map<String, Object?> overrides) => jsonEncode({
  'schemaVersion': 1,
  'nextNumber': 2,
  'notes': [
    {
      'id': 'n1',
      'page': 12,
      's': 2,
      'ch': 2,
      'text': 'x',
      'createdOn': 20000,
      'counted': <int>[],
      'pending': <int>[],
      'resolvedOn': null,
      ...overrides,
    },
  ],
});

void main() {
  group('NoteCodec', () {
    test('a book survives text and back', () {
      final back = NoteCodec.fromText(NoteCodec.toText(_sampleBook()));
      expect(back.nextNumber, 3);
      expect(back.notes.length, 2);

      final first = back.byId('n1')!;
      expect(first.page, 106);
      expect(first.s, 5);
      expect(first.ch, 13);
      expect(first.text, 'the verb forms');
      expect(first.counted, [const Day(20001), const Day(20003)]);
      expect(first.pending, [const Day(20004)]);
      expect(first.resolvedOn, isNull);

      final second = back.byId('n2')!;
      expect(second.text, 'a résumé: "quotes" and\nnewline');
      expect(second.resolvedOn, const Day(20005));
      expect(second.isArchived, isTrue);
    });

    test('days are written as day numbers, like the Q', () {
      final json = jsonDecode(NoteCodec.toText(_sampleBook())) as Map;
      final note = (json['notes'] as List).first as Map;
      expect(note['createdOn'], 20000);
      expect(note['counted'], [20001, 20003]);
      expect(json['schemaVersion'], 1);
    });

    test('each of these is a FormatException with a reason', () {
      final bad = <String, String>{
        'not json': 'not json at all',
        'not an object': '[]',
        'another schema': jsonEncode({
          'schemaVersion': 2,
          'nextNumber': 1,
          'notes': <Object>[],
        }),
        'page outside the table': _withNote({'page': 605}),
        'page zero': _withNote({'page': 0}),
        's outside the table': _withNote({'s': 115}),
        'ch outside the table': _withNote({'ch': 72}),
        'a day that is not a number': _withNote({
          'pending': ['yesterday'],
        }),
        'next number below 1': jsonEncode({
          'schemaVersion': 1,
          'nextNumber': 0,
          'notes': <Object>[],
        }),
      };
      for (final entry in bad.entries) {
        expect(
          () => NoteCodec.fromText(entry.value),
          throwsA(isA<FormatException>()),
          reason: entry.key,
        );
      }
    });

    test('a repeated id is refused', () {
      final text = jsonEncode({
        'schemaVersion': 1,
        'nextNumber': 3,
        'notes': [
          for (var i = 0; i < 2; i++)
            {
              'id': 'n1',
              'page': 12,
              's': 2,
              'ch': 2,
              'text': 'x',
              'createdOn': 20000,
              'counted': <int>[],
              'pending': <int>[],
              'resolvedOn': null,
            },
        ],
      });
      expect(() => NoteCodec.fromText(text), throwsFormatException);
    });
  });

  group('InMemoryNoteStore', () {
    test('no file is an empty book, not a problem', () async {
      final result = await InMemoryNoteStore().load();
      expect(result.book.notes, isEmpty);
      expect(result.problem, isNull);
    });

    test('save then load', () async {
      final store = InMemoryNoteStore();
      await store.save(_sampleBook());
      expect(store.saves, 1);
      final result = await store.load();
      expect(result.book.notes.length, 2);
      expect(result.problem, isNull);
    });

    test('a corrupt file is moved aside and the book starts empty', () async {
      final store = InMemoryNoteStore(clock: () => DateTime.utc(2026, 10, 10))
        ..text = '{broken';
      final result = await store.load();
      expect(result.book.notes, isEmpty);
      expect(result.problem, isNotNull);
      expect(result.quarantinedAs, startsWith('notes.json.bad-'));
      expect(store.quarantined[result.quarantinedAs], '{broken');
      expect(store.text, isNull);
    });
  });
}
