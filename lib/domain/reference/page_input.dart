import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';

/// A kind of number the user can type when logging: a page, a ch, an s.
///
/// The bare number is always a page ([PageUnit.page]); a letter prefix picks
/// another unit ("ch 3", "s 5"). The app works in pages everywhere, so every
/// unit only has to say which pages it covers ([rangeOf]).
///
/// To add a unit later: write one more subclass below and put it in
/// [PageUnit.all]. The parser ([PageInput]), the dialogs and the messages pick
/// it up from there.
///
/// "p", "ch" and "s" are used exactly as written, never expanded or translated.
abstract class PageUnit {
  const PageUnit(this.label, this.prefixes);

  /// How the unit is written in messages ("p", "ch", "s").
  final String label;

  /// What the user may type in front of the number, lowercase (the match
  /// ignores case).
  final List<String> prefixes;

  /// What a bare number means.
  static const PageUnit page = _PageUnit();

  /// A ch: its exact range in the table, shared boundary pages included.
  static const PageUnit ch = _ChUnit();

  /// An s: its exact range in the table, shared boundary pages included.
  static const PageUnit s = _SUnit();

  /// Every unit that can be typed. The first one is the default.
  static const List<PageUnit> all = [page, ch, s];

  /// The unit typed as [prefix] (any case), or null when none uses it.
  static PageUnit? byPrefix(String prefix) {
    final wanted = prefix.toLowerCase();
    for (final unit in all) {
      if (unit.prefixes.contains(wanted)) return unit;
    }
    return null;
  }

  /// Whether this unit exists for a Q of [totalPages] pages. The ch and s
  /// tables describe the 604-page Q only; a page always exists.
  bool isAvailableFor(int totalPages);

  /// The highest number of this unit for a Q of [totalPages] pages (the lowest
  /// is 1). Only called when [isAvailableFor] is true.
  int maxNumber(int totalPages);

  /// The pages unit number [number] covers. Only called for 1 to [maxNumber].
  PageRange rangeOf(int number);
}

final class _PageUnit extends PageUnit {
  const _PageUnit() : super('p', const ['p']);

  @override
  bool isAvailableFor(int totalPages) => true;

  @override
  int maxNumber(int totalPages) => totalPages;

  @override
  PageRange rangeOf(int number) => PageRange.single(number);
}

final class _ChUnit extends PageUnit {
  const _ChUnit() : super('ch', const ['ch']);

  @override
  bool isAvailableFor(int totalPages) => totalPages == ChTable.totalPages;

  @override
  int maxNumber(int totalPages) => ChTable.chCount;

  @override
  PageRange rangeOf(int number) => ChTable.instance.displayRange(number);
}

final class _SUnit extends PageUnit {
  const _SUnit() : super('s', const ['s']);

  @override
  bool isAvailableFor(int totalPages) => totalPages == ChTable.totalPages;

  @override
  int maxNumber(int totalPages) => STable.count;

  @override
  PageRange rangeOf(int number) =>
      PageRange(STable.firstPageOf(number), STable.lastPageOf(number));
}

/// What went wrong reading the From and To fields.
enum PageInputProblem {
  /// From is empty.
  missing,

  /// The text is not "number" or "letters number" (also: a number too long).
  malformed,

  /// Letters in front of the number that no unit uses.
  unknownUnit,

  /// The number is not one of the unit (ch 99, s 0, p 700).
  outOfRange,

  /// The unit has no table for this Q (ch and s need the 604-page Q).
  unavailable,

  /// From starts after the end of To.
  backwards,
}

/// The outcome of [PageInput.resolve].
sealed class PageInputResult {
  const PageInputResult();
}

/// Both fields were understood: [range] is what to log, in pages.
final class PageInputOk extends PageInputResult {
  const PageInputOk(this.range, {required this.usesUnits});

  final PageRange range;

  /// A ch or an s was typed, so the app worked the pages out (the dialog shows
  /// them, so the user can see what was understood).
  final bool usesUnits;
}

/// A field was not understood. Which fields of this are set depends on
/// [problem]: [text] for [PageInputProblem.malformed] (what was typed) and
/// [PageInputProblem.unknownUnit] (the letters); [unit] and [number] for
/// [PageInputProblem.outOfRange]; [unit] for [PageInputProblem.unavailable];
/// [max] for [PageInputProblem.outOfRange].
final class PageInputError extends PageInputResult {
  const PageInputError(
    this.problem, {
    this.text = '',
    this.unit,
    this.number,
    this.max,
  });

  final PageInputProblem problem;
  final String text;
  final PageUnit? unit;
  final int? number;
  final int? max;

  @override
  String toString() => 'PageInputError($problem, text: "$text", unit: '
      '${unit?.label}, number: $number, max: $max)';
}

/// Reads what the user typed for the pages of a log: pure Dart, no Flutter.
///
/// Each of From and To is a number with an optional unit in front, in any
/// case, with or without a space:
///
/// - `12` or `p 12`: page 12 (a bare number is a page);
/// - `ch 3` or `CH3`: ch 3;
/// - `s 5` or `s5`: s 5.
///
/// From uses the FIRST page of its unit and To the LAST page of its unit, so
/// "From ch 3 To ch 5" is every page of ch 3, 4 and 5, and "From ch 3 To p 40"
/// runs from the first page of ch 3 to page 40. A ch or an s is its exact range
/// in the table, shared boundary pages included (ch 13 is p 106 - 115). That
/// is the same page range the rest of the app shows for it, and the rules then
/// treat the pages as any other log (a shared page is logged twice, see
/// RULES.md).
///
/// An empty To means "the same as From": `12` is page 12 alone, `ch 3` is the
/// whole of ch 3.
abstract final class PageInput {
  /// Letters (maybe none), spaces (maybe none), then up to 6 digits.
  static final RegExp _shape = RegExp(r'^([A-Za-z]*)\s*(\d{1,6})$');

  /// The pages for [from] and [to], for a Q of [totalPages] pages.
  static PageInputResult resolve(
    String from,
    String to, {
    int totalPages = ChTable.totalPages,
  }) {
    final fromText = from.trim();
    if (fromText.isEmpty) {
      return const PageInputError(PageInputProblem.missing);
    }
    final toText = to.trim().isEmpty ? fromText : to.trim();

    final first = _read(fromText, totalPages);
    if (first.error != null) return first.error!;
    final last = _read(toText, totalPages);
    if (last.error != null) return last.error!;

    if (first.ref!.unit == last.ref!.unit &&
        first.ref!.number > last.ref!.number) {
      return const PageInputError(PageInputProblem.backwards);
    }
    final start = first.ref!.range.start;
    final end = last.ref!.range.end;
    if (start > end) {
      return const PageInputError(PageInputProblem.backwards);
    }
    return PageInputOk(
      PageRange(start, end),
      usesUnits:
          first.ref!.unit != PageUnit.page || last.ref!.unit != PageUnit.page,
    );
  }

  static ({_Ref? ref, PageInputError? error}) _read(
    String text,
    int totalPages,
  ) {
    final match = _shape.firstMatch(text);
    if (match == null) {
      return (
        ref: null,
        error: PageInputError(PageInputProblem.malformed, text: text),
      );
    }
    final prefix = match.group(1)!;
    final number = int.parse(match.group(2)!);

    final PageUnit? unit = prefix.isEmpty
        ? PageUnit.page
        : PageUnit.byPrefix(prefix);
    if (unit == null) {
      return (
        ref: null,
        error: PageInputError(PageInputProblem.unknownUnit, text: prefix),
      );
    }
    if (!unit.isAvailableFor(totalPages)) {
      return (
        ref: null,
        error: PageInputError(PageInputProblem.unavailable, unit: unit),
      );
    }
    final max = unit.maxNumber(totalPages);
    if (number < 1 || number > max) {
      return (
        ref: null,
        error: PageInputError(
          PageInputProblem.outOfRange,
          unit: unit,
          number: number,
          max: max,
        ),
      );
    }
    return (ref: _Ref(unit, number, unit.rangeOf(number)), error: null);
  }
}

/// One field, understood: its unit, its number, and the pages it covers.
final class _Ref {
  const _Ref(this.unit, this.number, this.range);

  final PageUnit unit;
  final int number;
  final PageRange range;
}
