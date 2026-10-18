import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/notes/models/note.dart';
import 'package:personaltskmng/notes/models/note_coverage.dart';

/// Every note, open and archived. Pure Dart and immutable: each operation
/// returns a new book (or this one when nothing changes), so "what if" is just
/// "apply and discard". Saved on its own, in `notes.json`, never inside the Q.
///
/// The rules in one place (also in RULES.md, Notes):
/// - [add]: a text note on a page, any number of them.
/// - [tap]: "I remembered". Accepted silently, one per note per day, only for
///   an open note. The tap is pending until its day is closed.
/// - [settle]: judges the pending taps of closed days. A tap counts only if a
///   successful R or L covering the note was logged that day, otherwise it
///   silently disappears. At [noteDaysToResolve] counted days the note
///   resolves: it leaves the open list and goes to the archive.
/// - [restore]: archive -> open, counting from 0 again.
/// - [delete]: only an archived note can be deleted.
final class NoteBook {
  const NoteBook({this.notes = const [], this.nextNumber = 1});

  final List<Note> notes;

  /// The number of the next note id ("n7"). Saved, so an id is never reused,
  /// even after a delete.
  final int nextNumber;

  List<Note> get open => [
    for (final n in notes)
      if (n.isOpen) n,
  ];

  List<Note> get archived => [
    for (final n in notes)
      if (n.isArchived) n,
  ];

  Note? byId(String id) {
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Adds a note on [page], filed under [s] and [ch]. Returns the new book and
  /// the note. Blank text is not a note: the book is returned unchanged and
  /// the note is null.
  (NoteBook, Note?) add({
    required int page,
    required int s,
    required int ch,
    required String text,
    required Day today,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (this, null);
    final note = Note(
      id: 'n$nextNumber',
      page: page,
      s: s,
      ch: ch,
      text: trimmed,
      createdOn: today,
    );
    return (NoteBook(notes: [...notes, note], nextNumber: nextNumber + 1), note);
  }

  /// "I remembered" on [today]. Accepted silently: an unknown or archived
  /// note, or a second tap the same day, changes nothing.
  NoteBook tap(String id, Day today) {
    final note = byId(id);
    if (note == null || !note.isOpen) return this;
    if (note.pending.contains(today) || note.counted.contains(today)) {
      return this;
    }
    return _replace(note.copyWith(pending: [...note.pending, today]));
  }

  /// The days before [today] that have a pending tap on an open note: the days
  /// whose log [settle] needs.
  Set<Day> daysToJudge(Day today) => {
    for (final n in notes)
      if (n.isOpen)
        for (final d in n.pending)
          if (d.isBefore(today)) d,
  };

  /// Judges every pending tap of a day before [today] (the day is closed).
  /// [loggedOn] gives the ranges of the successful R and L logged on a day.
  /// A tap on a day that [NoteCoverage] covers is counted, any other tap is
  /// dropped without a trace. Taps of [today] (or later) stay pending. A note
  /// that reaches [noteDaysToResolve] counted days is resolved on the day that
  /// reached it.
  NoteBook settle(
    Day today, {
    required Iterable<PageRange> Function(Day day) loggedOn,
  }) {
    var changed = false;
    final next = <Note>[];
    for (final note in notes) {
      final judged = _settleNote(note, today, loggedOn);
      if (!identical(judged, note)) changed = true;
      next.add(judged);
    }
    return changed ? NoteBook(notes: next, nextNumber: nextNumber) : this;
  }

  static Note _settleNote(
    Note note,
    Day today,
    Iterable<PageRange> Function(Day day) loggedOn,
  ) {
    if (!note.isOpen) return note;
    final closed = [
      for (final d in note.pending)
        if (d.isBefore(today)) d,
    ]..sort();
    if (closed.isEmpty) return note;

    final counted = [...note.counted];
    Day? resolvedOn;
    for (final day in closed) {
      if (counted.contains(day)) continue;
      if (!NoteCoverage.covers(note, loggedOn(day))) continue;
      counted.add(day);
      if (counted.length >= noteDaysToResolve) {
        resolvedOn = day;
        break;
      }
    }
    counted.sort();
    final stillPending = resolvedOn != null
        ? <Day>[]
        : [
            for (final d in note.pending)
              if (!d.isBefore(today)) d,
          ];
    return note.copyWith(
      counted: counted,
      pending: stillPending,
      resolvedOn: resolvedOn,
    );
  }

  /// Archive -> open. The note starts counting again from 0 (its old counted
  /// days are cleared), otherwise it would resolve again at once. An open or
  /// unknown note changes nothing.
  NoteBook restore(String id) {
    final note = byId(id);
    if (note == null || !note.isArchived) return this;
    return _replace(
      note.copyWith(counted: const <Day>[], pending: const <Day>[], resolvedOn: null),
    );
  }

  /// Deletes an archived note. An open or unknown note is never deleted: the
  /// delete exists only in the archive.
  NoteBook delete(String id) {
    final note = byId(id);
    if (note == null || !note.isArchived) return this;
    return NoteBook(
      notes: [
        for (final n in notes)
          if (n.id != id) n,
      ],
      nextNumber: nextNumber,
    );
  }

  NoteBook _replace(Note note) => NoteBook(
    notes: [
      for (final n in notes)
        if (n.id == note.id) note else n,
    ],
    nextNumber: nextNumber,
  );
}
