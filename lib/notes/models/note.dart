import 'package:personaltskmng/domain/models/day.dart';

/// How many counted days resolve a note. The days need not be consecutive.
const int noteDaysToResolve = 5;

/// One text note about a page. Pure Dart, immutable. Notes live in their own
/// file (see `NoteStore`), apart from the Q, and no rule, planner or cost reads
/// them.
///
/// A note belongs to one [page]. Its [s] and [ch] are the unit pair it is filed
/// under (the page's own pair, or the one the user chose when the page is
/// shared by several s or ch). They decide which s, ch and part screens show
/// the note; the page screen always shows it.
///
/// "I remembered": one tap per note per day. A tap is first only PENDING
/// ([pending]); it becomes a counted day ([counted]) at the end of its day if a
/// successful R or L covering the note was logged that day, and silently
/// disappears otherwise (see `NoteBook.settle`). [count] therefore includes
/// only closed days; today's tap is [tappedOn] but not yet counted.
final class Note {
  const Note({
    required this.id,
    required this.page,
    required this.s,
    required this.ch,
    required this.text,
    required this.createdOn,
    this.counted = const [],
    this.pending = const [],
    this.resolvedOn,
  });

  /// Unique id, never reused.
  final String id;

  /// The page (1-based) the note belongs to.
  final int page;

  /// The s the note is filed under (1 to 114).
  final int s;

  /// The ch the note is filed under (1 to 71).
  final int ch;

  final String text;

  final Day createdOn;

  /// Closed days that counted, ascending, no duplicates.
  final List<Day> counted;

  /// Days with a tap that is not yet judged (normally just today).
  final List<Day> pending;

  /// The day the note reached [noteDaysToResolve] counted days and went to the
  /// archive; null while it is open.
  final Day? resolvedOn;

  bool get isOpen => resolvedOn == null;

  bool get isArchived => resolvedOn != null;

  /// Counted days so far (closed days only), the "3" of "3/5".
  int get count => counted.length;

  /// Whether [day] has a tap that is still waiting to be judged.
  bool tappedOn(Day day) => pending.contains(day);

  static const Object _keep = Object();

  /// Pass `resolvedOn: null` to clear it; omit to keep the current value.
  Note copyWith({
    List<Day>? counted,
    List<Day>? pending,
    Object? resolvedOn = _keep,
  }) => Note(
    id: id,
    page: page,
    s: s,
    ch: ch,
    text: text,
    createdOn: createdOn,
    counted: counted ?? this.counted,
    pending: pending ?? this.pending,
    resolvedOn: identical(resolvedOn, _keep)
        ? this.resolvedOn
        : resolvedOn as Day?,
  );

  @override
  String toString() =>
      'Note($id p$page s$s ch$ch count=$count pending=$pending '
      'resolvedOn=$resolvedOn)';
}
