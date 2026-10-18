import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/models/note_book.dart';

/// The result of loading `notes.json`.
///
/// A file that cannot be read or decoded is moved aside (to
/// `notes.json.bad-<timestamp>`, [quarantinedAs]) and the app carries on with an
/// empty book and the reason in [problem]; the damaged file is never
/// overwritten, so nothing is lost. A missing file is not a problem: it is an
/// empty book.
final class NoteLoadResult {
  const NoteLoadResult(this.book, {this.problem, this.quarantinedAs});

  final NoteBook book;

  /// Why the stored file could not be used, or null.
  final String? problem;

  /// Where the unreadable file was moved, or null.
  final String? quarantinedAs;
}

/// Where the notes live: ONE file of their own, apart from `state.json` (the
/// Q) and `settings.json`. Saving can throw; the caller decides what to tell
/// the user. Pure Dart (no Flutter, no dart:io).
abstract interface class NoteStore {
  Future<NoteLoadResult> load();

  Future<void> save(NoteBook book);
}

/// A [NoteStore] that keeps the file as text in memory (for tests and
/// previews). It runs the same codec as the file store, so a round trip through
/// it is a real encode and decode, and a bad file is "renamed" the same way.
final class InMemoryNoteStore implements NoteStore {
  InMemoryNoteStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const String fileName = 'notes.json';

  final DateTime Function() _clock;

  /// The content of `notes.json`, or null when there is no such file. Tests may
  /// set it to simulate a corrupt file.
  String? text;

  /// Files moved aside after a failed load: name -> text.
  final Map<String, String> quarantined = {};

  /// How many times the file was written.
  int saves = 0;

  /// Tests set this to make [save] throw.
  bool failOnSave = false;

  @override
  Future<NoteLoadResult> load() async {
    final stored = text;
    if (stored == null) return const NoteLoadResult(NoteBook());
    try {
      return NoteLoadResult(NoteCodec.fromText(stored));
    } on FormatException catch (e) {
      final name = '$fileName.bad-${_clock().millisecondsSinceEpoch}';
      quarantined[name] = stored;
      text = null;
      return NoteLoadResult(
        const NoteBook(),
        problem: '$fileName: ${e.message}',
        quarantinedAs: name,
      );
    }
  }

  @override
  Future<void> save(NoteBook book) async {
    if (failOnSave) throw StateError('the notes could not be saved');
    text = NoteCodec.toText(book);
    saves++;
  }
}
