import 'package:personaltskmng/domain/reference/quran_divisions.dart';

/// Where the small field of the Go to sheet can send the reader.
sealed class GoToTarget {
  const GoToTarget();
}

/// An ayah (`2:255`).
final class GoToAyah extends GoToTarget {
  const GoToAyah(this.ayah);

  final AyahRef ayah;
}

/// A page of the chosen print (`p 42`, or just `42`).
final class GoToPage extends GoToTarget {
  const GoToPage(this.page);

  final int page;
}

/// A juz (`j 15`).
final class GoToJuz extends GoToTarget {
  const GoToJuz(this.juz);

  final int juz;
}

/// A hizb (`hz 29`).
final class GoToHizb extends GoToTarget {
  const GoToHizb(this.hizb);

  final int hizb;
}

/// A surah (`s 2`).
final class GoToSurah extends GoToTarget {
  const GoToSurah(this.surah);

  final int surah;
}

/// Why a text is not a place.
enum GoToProblem {
  /// Not something the field understands.
  unknown,

  /// A number, but not one that exists (no hizb 61, no 2:287).
  outOfRange,
}

/// What the field made of a text: a target, a problem, or (for an empty field)
/// neither.
typedef GoToResult = ({GoToTarget? target, GoToProblem? problem});

/// Reads what the reader types in the Go to sheet: `2:255`, `p 42`, `j 15`,
/// `hz 29`, `s 2`; a bare number is a page, like everywhere in the app.
///
/// The letters are chosen not to clash with the planning terms (Q, M, R, D, ND,
/// C, F). The case and the spaces do not matter (`J15`, `hz29`). Pure Dart; a
/// page is checked against 1 to 604 only here, which print it is in is the
/// layout pack's business.
abstract final class GoToInput {
  /// The most pages the book has.
  static const int pageCount = 604;

  static final RegExp _ayah = RegExp(r'^(\d{1,3})\s*[:.]\s*(\d{1,3})$');
  static final RegExp _prefixed = RegExp(r'^([a-z]+)\s*(\d{1,4})$');
  static final RegExp _number = RegExp(r'^\d{1,4}$');

  static const GoToResult _empty = (target: null, problem: null);
  static const GoToResult _unknown = (
    target: null,
    problem: GoToProblem.unknown,
  );
  static const GoToResult _outOfRange = (
    target: null,
    problem: GoToProblem.outOfRange,
  );

  static GoToResult parse(String text) {
    final input = text.trim().toLowerCase();
    if (input.isEmpty) return _empty;

    final ayah = _ayah.firstMatch(input);
    if (ayah != null) {
      final ref = AyahRef(int.parse(ayah.group(1)!), int.parse(ayah.group(2)!));
      return ref.isValid
          ? (target: GoToAyah(ref), problem: null)
          : _outOfRange;
    }

    if (_number.hasMatch(input)) return _page(int.parse(input));

    final prefixed = _prefixed.firstMatch(input);
    if (prefixed == null) return _unknown;
    final number = int.parse(prefixed.group(2)!);
    switch (prefixed.group(1)) {
      case 'p' || 'page':
        return _page(number);
      case 'j' || 'juz':
        return number >= 1 && number <= QuranDivisions.juzCount
            ? (target: GoToJuz(number), problem: null)
            : _outOfRange;
      case 'hz' || 'hizb':
        return number >= 1 && number <= QuranDivisions.hizbCount
            ? (target: GoToHizb(number), problem: null)
            : _outOfRange;
      case 's' || 'surah':
        return number >= 1 && number <= QuranDivisions.surahCount
            ? (target: GoToSurah(number), problem: null)
            : _outOfRange;
    }
    return _unknown;
  }

  static GoToResult _page(int page) => page >= 1 && page <= pageCount
      ? (target: GoToPage(page), problem: null)
      : _outOfRange;
}
