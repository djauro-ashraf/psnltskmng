import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';

/// Open-note counts per unit, built once from a [NoteBook] for the lists and
/// rows that show "how many open notes". Pure Dart.
///
/// A note is counted where it is filed: on its page, under its s, under its ch
/// and in the part (its s inside its ch). A ch that is merged is one unit: its
/// count is simply the count of its ch, whatever page of it the note is on.
final class NoteIndex {
  NoteIndex._(this._byPage, this._byS, this._byCh, this._byPart, this.total);

  /// An index with no notes.
  static final NoteIndex empty = NoteIndex._(const {}, const {}, const {}, const {}, 0);

  factory NoteIndex.of(NoteBook book) {
    final byPage = <int, int>{};
    final byS = <int, int>{};
    final byCh = <int, int>{};
    final byPart = <int, int>{};
    var total = 0;
    for (final Note note in book.notes) {
      if (!note.isOpen) continue;
      total++;
      byPage[note.page] = (byPage[note.page] ?? 0) + 1;
      byS[note.s] = (byS[note.s] ?? 0) + 1;
      byCh[note.ch] = (byCh[note.ch] ?? 0) + 1;
      final key = _partKey(note.s, note.ch);
      byPart[key] = (byPart[key] ?? 0) + 1;
    }
    return NoteIndex._(byPage, byS, byCh, byPart, total);
  }

  static int _partKey(int s, int ch) => s * 1000 + ch;

  final Map<int, int> _byPage;
  final Map<int, int> _byS;
  final Map<int, int> _byCh;
  final Map<int, int> _byPart;

  /// All open notes.
  final int total;

  int onPage(int page) => _byPage[page] ?? 0;

  int inS(int s) => _byS[s] ?? 0;

  int inCh(int ch) => _byCh[ch] ?? 0;

  int inPart(int s, int ch) => _byPart[_partKey(s, ch)] ?? 0;
}
