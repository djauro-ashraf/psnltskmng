import 'dart:io';

import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note_book.dart';

/// [NoteStore] on `notes.json` in [directory] (the app documents directory,
/// given by the composition root, next to `state.json`). Same care as the Q's
/// file store:
///
/// - **Atomic writes.** Each save writes `notes.json.tmp`, flushes it, then
///   renames it over the target. A crash before the rename leaves the old file
///   untouched; a leftover `.tmp` is never read. Saves are queued so two writes
///   never overlap.
/// - **Bad file.** A file that cannot be read or decoded is renamed to
///   `notes.json.bad-<timestamp>` and the load returns an empty book with the
///   reason; the bad file is never written over.
final class FileNoteStore implements NoteStore {
  FileNoteStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const String fileName = 'notes.json';

  final Directory directory;
  final DateTime Function() _clock;

  Future<void> _tail = Future<void>.value();

  String _path(String name) => '${directory.path}${Platform.pathSeparator}$name';

  File _file(String name) => File(_path(name));

  @override
  Future<NoteLoadResult> load() async {
    try {
      final file = _file(fileName);
      if (!await file.exists()) return const NoteLoadResult(NoteBook());
      final text = await file.readAsString();
      return NoteLoadResult(NoteCodec.fromText(text));
    } on FormatException catch (e) {
      final moved = await _quarantine();
      return NoteLoadResult(
        const NoteBook(),
        problem: '$fileName: ${e.message}${moved.note}',
        quarantinedAs: moved.name,
      );
    } catch (e) {
      final moved = await _quarantine();
      return NoteLoadResult(
        const NoteBook(),
        problem: '$fileName: cannot be read ($e)${moved.note}',
        quarantinedAs: moved.name,
      );
    }
  }

  @override
  Future<void> save(NoteBook book) =>
      _writeAtomic(fileName, NoteCodec.toText(book));

  /// Moves the file aside as `notes.json.bad-<timestamp>`.
  Future<({String? name, String note})> _quarantine() async {
    final badName = '$fileName.bad-${_clock().millisecondsSinceEpoch}';
    try {
      await _file(fileName).rename(_path(badName));
      return (name: badName, note: ' (moved to $badName)');
    } catch (e) {
      return (name: null, note: ' (could not be moved aside: $e)');
    }
  }

  /// Write `<name>.tmp`, flush, rename over `<name>`. Serialized.
  Future<void> _writeAtomic(String name, String text) {
    final job = _tail.then((_) async {
      await directory.create(recursive: true);
      final tmp = _file('$name.tmp');
      RandomAccessFile? out;
      try {
        out = await tmp.open(mode: FileMode.write);
        await out.writeString(text);
        await out.flush();
        await out.close();
        out = null;
        await tmp.rename(_path(name));
      } catch (_) {
        try {
          await out?.close();
        } catch (_) {}
        try {
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
        rethrow;
      }
    });
    _tail = job.then<void>((_) {}, onError: (Object _) {});
    return job;
  }
}
