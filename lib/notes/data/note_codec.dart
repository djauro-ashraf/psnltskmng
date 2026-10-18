import 'dart:convert';

import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/planning/data/json_reader.dart';

/// Text <-> [NoteBook] for `notes.json`, shared by every store so that the
/// in-memory store and the file store read exactly the same way. Pure Dart.
///
/// [fromText] throws a [FormatException] with the reason when the text is not
/// valid JSON, not the expected shape, from another schema, or holds a note
/// that cannot be real (a page, s or ch outside the table, a repeated id).
/// Days are written as day numbers (days since 1970-01-01), like the Q.
abstract final class NoteCodec {
  static const int schemaVersion = 1;

  static String toText(NoteBook book) => jsonEncode({
    'schemaVersion': schemaVersion,
    'nextNumber': book.nextNumber,
    'notes': [for (final note in book.notes) _noteToJson(note)],
  });

  static NoteBook fromText(String text) {
    try {
      final o = JsonObject.of(jsonDecode(text), 'notes');
      final version = o.integer('schemaVersion');
      if (version != schemaVersion) {
        throw FormatException(
          'notes.schemaVersion: $version is not supported (expected '
          '$schemaVersion)',
        );
      }
      final notes = [for (final n in o.objects('notes')) _noteFromJson(n)];
      final ids = <String>{};
      for (final note in notes) {
        if (!ids.add(note.id)) {
          throw FormatException('notes: the id "${note.id}" is used twice');
        }
      }
      final next = o.integer('nextNumber');
      if (next < 1) {
        throw FormatException('notes.nextNumber: must be at least 1, got $next');
      }
      return NoteBook(notes: notes, nextNumber: next);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('notes: unreadable ($e)');
    }
  }

  static Map<String, Object?> _noteToJson(Note note) => {
    'id': note.id,
    'page': note.page,
    's': note.s,
    'ch': note.ch,
    'text': note.text,
    'createdOn': note.createdOn.epochDay,
    'counted': [for (final d in note.counted) d.epochDay],
    'pending': [for (final d in note.pending) d.epochDay],
    'resolvedOn': note.resolvedOn?.epochDay,
  };

  static Note _noteFromJson(JsonObject o) {
    final page = o.integer('page');
    final s = o.integer('s');
    final ch = o.integer('ch');
    if (page < 1 || page > ChTable.totalPages) {
      throw FormatException('${o.path}.page: $page is outside the table');
    }
    if (s < 1 || s > ChTable.sCount) {
      throw FormatException('${o.path}.s: $s is outside the table');
    }
    if (ch < 1 || ch > ChTable.chCount) {
      throw FormatException('${o.path}.ch: $ch is outside the table');
    }
    final counted = _days(o, 'counted')..sort();
    return Note(
      id: o.string('id'),
      page: page,
      s: s,
      ch: ch,
      text: o.string('text'),
      createdOn: o.day('createdOn'),
      counted: counted,
      pending: _days(o, 'pending')..sort(),
      resolvedOn: o.dayOrNull('resolvedOn'),
    );
  }

  static List<Day> _days(JsonObject o, String key) {
    final out = <Day>[];
    final items = o.list(key);
    for (var i = 0; i < items.length; i++) {
      final v = items[i];
      if (v is! int) {
        throw FormatException('${o.path}.$key[$i]: expected a day number, got $v');
      }
      final day = Day(v);
      if (!out.contains(day)) out.add(day);
    }
    return out;
  }
}
