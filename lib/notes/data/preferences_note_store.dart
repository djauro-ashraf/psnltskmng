import 'package:personaltskmng/notes/data/note_codec.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [NoteStore] backed by [SharedPreferencesWithCache], for web and other
/// platforms without a usable filesystem (like `PreferencesAppStateStore`). The
/// notes are one entry of their own, apart from the Q's.
final class PreferencesNoteStore implements NoteStore {
  PreferencesNoteStore(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final SharedPreferencesWithCache _prefs;
  final DateTime Function() _clock;

  static const String key = 'notes_v1';

  @override
  Future<NoteLoadResult> load() async {
    final text = _prefs.getString(key);
    if (text == null) return const NoteLoadResult(NoteBook());
    try {
      return NoteLoadResult(NoteCodec.fromText(text));
    } on FormatException catch (e) {
      final badKey = '$key.bad_${_clock().millisecondsSinceEpoch}';
      await _prefs.setString(badKey, text);
      await _prefs.remove(key);
      return NoteLoadResult(
        const NoteBook(),
        problem: 'notes: ${e.message}',
        quarantinedAs: badKey,
      );
    }
  }

  @override
  Future<void> save(NoteBook book) async {
    await _prefs.setString(key, NoteCodec.toText(book));
  }
}
