import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/notes/data/day_log.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';

/// Loads, holds and saves the notes (`notes.json`), and runs the day-end check
/// of the "I remembered" taps. Pure Dart; the Riverpod providers only expose
/// it.
///
/// - **Separate from the Q.** The notes have their own store and the controller
///   never touches `state.json`, the settings or the planner. The only thing it
///   reads from the planning side is the day log (through [DayLogReader]).
/// - **One writer at a time.** Every change runs through one queue, so a settle
///   and a tap never overlap.
/// - **Save first.** A change is kept in memory only after it was saved: when
///   saving throws, the book is unchanged and the error reaches the caller.
final class NotesController {
  NotesController({required this.store, this._dayLog});

  final NoteStore store;
  final DayLogReader? _dayLog;

  NoteBook _book = const NoteBook();
  String? _loadProblem;
  Future<void> _tail = Future<void>.value();

  /// The notes as they are now.
  NoteBook get book => _book;

  /// Why the stored file could not be used at the last [load] (it was moved
  /// aside and the book started empty), or null.
  String? get loadProblem => _loadProblem;

  /// Reads `notes.json`. Never throws for a bad file (see [NoteLoadResult]).
  Future<void> load() async {
    final result = await store.load();
    _book = result.book;
    _loadProblem = result.problem;
  }

  /// Adds a note on [page] filed under [s] and [ch]. Returns the note, or null
  /// when [text] is blank (nothing is saved then).
  Future<Note?> add({
    required int page,
    required int s,
    required int ch,
    required String text,
    required Day today,
  }) => _serial(() async {
    await _settle(today);
    final (next, note) = _book.add(
      page: page,
      s: s,
      ch: ch,
      text: text,
      today: today,
    );
    if (note == null) return null;
    await _commit(next);
    return note;
  });

  /// "I remembered" on [today]. Taps of earlier days that are still waiting
  /// are judged first, so a tap is never judged against the wrong day.
  Future<void> tap(String id, Day today) => _serial(() async {
    await _settle(today);
    await _commit(_book.tap(id, today));
  });

  /// The day-end check: judges the pending taps of every day before [today].
  /// Nothing is judged when the day log cannot be read (the taps wait for the
  /// next try).
  Future<void> settle(Day today) => _serial(() => _settle(today));

  /// Archive -> open, counting from 0 again.
  Future<void> restore(String id) =>
      _serial(() => _commit(_book.restore(id)));

  /// Deletes an archived note (an open note is never deleted).
  Future<void> delete(String id) => _serial(() => _commit(_book.delete(id)));

  /// Replaces every note with [book] (a restored backup). Saved first, like any
  /// other change; the pending taps in it are judged by the next [settle].
  Future<void> replaceWith(NoteBook book) => _serial(() => _commit(book));

  Future<void> _settle(Day today) async {
    final days = _book.daysToJudge(today);
    if (days.isEmpty) return;
    final reader = _dayLog;
    final logged = <Day, List<PageRange>>{};
    for (final day in days) {
      if (reader == null) {
        logged[day] = const [];
        continue;
      }
      try {
        logged[day] = await reader(day);
      } catch (_) {
        // The log of that day cannot be read right now: judge nothing, the
        // taps stay pending and the next settle tries again.
        return;
      }
    }
    await _commit(
      _book.settle(today, loggedOn: (day) => logged[day] ?? const []),
    );
  }

  Future<void> _commit(NoteBook next) async {
    if (identical(next, _book)) return;
    await store.save(next);
    _book = next;
  }

  Future<T> _serial<T>(Future<T> Function() job) {
    final run = _tail.then((_) => job());
    _tail = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }
}
