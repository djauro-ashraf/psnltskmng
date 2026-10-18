import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_book.dart';
import 'package:personaltskmng/notes/models/note_index.dart';

/// The notes as the screens read them: the book, today, and the open-note
/// counts. Immutable; a new one is published after every change.
final class NotesState {
  NotesState({required this.book, required this.today})
    : index = NoteIndex.of(book);

  final NoteBook book;

  /// The day the screens treat as today (a tap of this day shows as a faint
  /// tick).
  final Day today;

  final NoteIndex index;

  /// The open notes for which [test] holds, by page (the order they were added
  /// in within a page).
  List<Note> openWhere(bool Function(Note note) test) =>
      byPage([for (final n in book.notes) if (n.isOpen && test(n)) n]);

  /// The archived notes for which [test] holds, the latest resolved first.
  List<Note> archivedWhere(bool Function(Note note) test) {
    final found = <Note>[
      for (final n in book.notes)
        if (n.isArchived && test(n)) n,
    ];
    final order = {for (var i = 0; i < found.length; i++) found[i].id: i};
    found.sort((a, b) {
      final byDay = b.resolvedOn!.compareTo(a.resolvedOn!);
      return byDay != 0 ? byDay : order[b.id]!.compareTo(order[a.id]!);
    });
    return found;
  }

  /// [notes] by page; notes of the same page keep their order (sorting alone
  /// is not stable).
  static List<Note> byPage(List<Note> notes) {
    final order = {for (var i = 0; i < notes.length; i++) notes[i].id: i};
    final sorted = [...notes];
    sorted.sort((a, b) {
      final byPage = a.page.compareTo(b.page);
      return byPage != 0 ? byPage : order[a.id]!.compareTo(order[b.id]!);
    });
    return sorted;
  }
}

/// The notes' view model. Every change goes through the [NotesController]
/// (which saves first); the new book is published only afterwards.
///
/// The day-end check ([refresh]) runs when the notes are first read and
/// whenever a new calendar day starts (Today calls it), and before every tap.
class NotesViewModel extends Notifier<NotesState> {
  NotesController get _controller => ref.read(notesControllerProvider);

  Day _today() => Day.fromDateTime(ref.read(todayClockProvider)());

  @override
  NotesState build() {
    Future<void>.microtask(refresh);
    return NotesState(book: _controller.book, today: _today());
  }

  /// Judges the pending taps of closed days (see `NoteBook.settle`) and shows
  /// the result. Never throws.
  Future<void> refresh() async {
    try {
      await _controller.settle(_today());
    } catch (_) {
      // Could not save the result: the taps stay as they were.
    }
    _publish();
  }

  /// Adds a note. False when it could not be saved (or [text] is blank).
  Future<bool> add({
    required int page,
    required int s,
    required int ch,
    required String text,
  }) => _run(
    () async =>
        await _controller.add(
          page: page,
          s: s,
          ch: ch,
          text: text,
          today: _today(),
        ) !=
        null,
  );

  /// "I remembered". Accepted silently; false only when saving failed.
  Future<bool> remembered(String id) =>
      _run(() async {
        await _controller.tap(id, _today());
        return true;
      });

  /// Archive -> open.
  Future<bool> restore(String id) => _run(() async {
    await _controller.restore(id);
    return true;
  });

  /// Deletes an archived note.
  Future<bool> delete(String id) => _run(() async {
    await _controller.delete(id);
    return true;
  });

  Future<bool> _run(Future<bool> Function() action) async {
    var ok = false;
    try {
      ok = await action();
    } catch (_) {
      ok = false;
    }
    _publish();
    return ok;
  }

  void _publish() {
    if (!ref.mounted) return;
    final book = _controller.book;
    final today = _today();
    // Nothing changed (the book is replaced only when something did): keep the
    // state, so nothing that reads the notes is rebuilt for nothing.
    if (identical(state.book, book) && state.today == today) return;
    state = NotesState(book: book, today: today);
  }
}

final notesViewModelProvider = NotifierProvider<NotesViewModel, NotesState>(
  NotesViewModel.new,
);
