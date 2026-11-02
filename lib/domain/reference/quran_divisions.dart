import 'package:personaltskmng/domain/reference/quran_divisions_data.dart';

/// One ayah: its surah (1 to 114) and its number inside it.
///
/// The text, the page and the other facts of an ayah are not here; this is only
/// a place in the Quran, ordered like the book. Pure Dart. "s" stays the
/// letter the app writes for a surah; the words juz, hizb and ruku are used as
/// they are and never translated.
final class AyahRef implements Comparable<AyahRef> {
  const AyahRef(this.surah, this.ayah);

  final int surah;
  final int ayah;

  static final RegExp _pattern = RegExp(r'^(\d{1,3})\s*:\s*(\d{1,3})$');

  /// Reads "2:255". Null when the text is not that, or the ayah does not exist
  /// (no 2:287, no 115:1).
  static AyahRef? tryParse(String text) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;
    final ref = AyahRef(int.parse(match.group(1)!), int.parse(match.group(2)!));
    return ref.isValid ? ref : null;
  }

  /// True when the surah and the ayah exist.
  bool get isValid =>
      surah >= 1 &&
      surah <= QuranDivisions.surahCount &&
      ayah >= 1 &&
      ayah <= QuranDivisions.ayahCountOf(surah);

  /// "2:255", the form the packs and the screens use.
  String get key => '$surah:$ayah';

  /// The place among all 6,236 ayahs, from 0 (1:1). Throws a [RangeError] for an
  /// ayah that does not exist.
  int get index => QuranDivisions.indexOf(this);

  @override
  int compareTo(AyahRef other) =>
      surah != other.surah ? surah.compareTo(other.surah) : ayah.compareTo(other.ayah);

  bool operator <(AyahRef other) => compareTo(other) < 0;
  bool operator <=(AyahRef other) => compareTo(other) <= 0;
  bool operator >(AyahRef other) => compareTo(other) > 0;
  bool operator >=(AyahRef other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) =>
      other is AyahRef && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  @override
  String toString() => key;
}

/// A run of ayahs, both ends included.
final class AyahRange {
  AyahRange(this.first, this.last)
    : assert(first <= last, 'a range runs forward');

  final AyahRef first;
  final AyahRef last;

  bool contains(AyahRef ref) => ref >= first && ref <= last;

  /// How many ayahs it holds.
  int get length => last.index - first.index + 1;

  @override
  bool operator ==(Object other) =>
      other is AyahRange && other.first == first && other.last == last;

  @override
  int get hashCode => Object.hash(first, last);

  @override
  String toString() => '$first-$last';
}

/// One ruku. It is named by its number INSIDE its surah (a printed Quran shows
/// that number, never the one from 1 to 558) and the rukus the surah has.
/// No ruku crosses a surah border.
final class Ruku {
  const Ruku({
    required this.surah,
    required this.number,
    required this.count,
    required this.first,
    required this.last,
  });

  final int surah;

  /// 1 to [count].
  final int number;

  /// How many rukus the surah has.
  final int count;

  final AyahRef first;
  final AyahRef last;

  /// How many ayahs it holds.
  int get ayahCount => last.ayah - first.ayah + 1;

  AyahRange get range => AyahRange(first, last);

  @override
  bool operator ==(Object other) =>
      other is Ruku && other.surah == surah && other.number == number;

  @override
  int get hashCode => Object.hash(surah, number);

  @override
  String toString() => 'Ruku $number of s $surah';
}

/// Where an ayah sits in every division at once.
final class DivisionPosition {
  const DivisionPosition({
    required this.ayah,
    required this.juz,
    required this.hizb,
    required this.ruku,
  });

  final AyahRef ayah;

  /// 1 to 30.
  final int juz;

  /// 1 to 60.
  final int hizb;

  final Ruku ruku;

  int get surah => ayah.surah;

  /// 1 or 2: which half of its juz the hizb is.
  int get halfOfJuz => QuranDivisions.halfOfJuz(hizb);
}

/// What begins at one ayah. Several things can begin together (the first ayah
/// of Al-Isra begins the surah, a juz, a hizb and a ruku), which is why a
/// banner is built from this and not from one fact.
final class DivisionStarts {
  const DivisionStarts({
    required this.ayah,
    required this.surahStart,
    this.juz,
    this.hizb,
    this.ruku,
  });

  final AyahRef ayah;

  /// The ayah is the first of its surah.
  final bool surahStart;

  /// The juz that begins here, if one does.
  final int? juz;

  /// The hizb that begins here, if one does.
  final int? hizb;

  /// The ruku that begins here, if one does.
  final Ruku? ruku;

  bool get isEmpty => !surahStart && juz == null && hizb == null && ruku == null;
}

/// The divisions a unit of reading can follow.
enum DivisionUnit { surah, juz, hizb, ruku }

/// The 30 juz, 60 hizb and 558 rukus of the Quran, by where each one starts,
/// with the lookups the reader needs: where an ayah is, what begins at an ayah,
/// the ayahs of a unit.
///
/// DISPLAY AND NAVIGATION ONLY. No rule, planner, validator, snapshot or AI
/// prompt reads it, and nothing under `lib/domain/rules`, `lib/planning` or
/// `lib/ai` imports it (`test/domain/quran_divisions_test.dart` checks that).
/// The tables come from `quran_divisions_data.dart`, made from the reader's
/// `quran_divisions.json` by `tool/build_quran_divisions.py`; pages are NOT part
/// of it (the layout pack of the chosen print knows them). Quarters (rub') are
/// out on purpose.
///
/// The index behind the lookups is built the first time one is asked for, which
/// is when the reader (or the juz list) is opened, never at app start.
abstract final class QuranDivisions {
  static const int surahCount = 114;
  static const int juzCount = 30;
  static const int hizbCount = 60;
  static const int rukuCount = 558;
  static const int ayahCount = 6236;

  /// FLAG, off on purpose. The reader asked that "Meccan" / "Medinan" be shown
  /// only if they can be taken from the same open source as the other division
  /// numbers. That was NOT confirmed (the list below is the usual one of Tanzil
  /// and Quran.com, typed in, not read from the source of `quran_divisions.json`).
  /// While this is false the banner leaves the word out. To turn it on: check
  /// where the list may come from, correct it if needed, then set this to true.
  static const bool showRevelationPlace = false;

  /// The surahs the usual lists (Tanzil, Quran.com) call Medinan; every other
  /// one is Meccan. A label only (see [showRevelationPlace]).
  static const Set<int> _medinan = {
    2, 3, 4, 5, 8, 9, 13, 22, 24, 33, 47, 48, 49, 55, 57, 58, 59, 60, 61, 62, //
    63, 64, 65, 66, 76, 98, 99, 110,
  };

  /// True for a Medinan surah, false for a Meccan one.
  static bool isMedinan(int surah) {
    RangeError.checkValueInInterval(surah, 1, surahCount, 'surah');
    return _medinan.contains(surah);
  }

  static final _Index _index = _Index.build();

  /// How many ayahs surah [surah] has.
  static int ayahCountOf(int surah) {
    RangeError.checkValueInInterval(surah, 1, surahCount, 'surah');
    return QuranDivisionsData.surahAyahCounts[surah - 1];
  }

  /// The place of [ref] among all the ayahs, from 0.
  static int indexOf(AyahRef ref) {
    RangeError.checkValueInInterval(ref.surah, 1, surahCount, 'surah');
    RangeError.checkValueInInterval(ref.ayah, 1, ayahCountOf(ref.surah), 'ayah');
    return _index.surahOffset[ref.surah - 1] + ref.ayah - 1;
  }

  /// The ayah at place [index] (0 to [ayahCount] - 1).
  static AyahRef fromIndex(int index) {
    RangeError.checkValueInInterval(index, 0, ayahCount - 1, 'index');
    final surah = _lastAtOrBefore(_index.surahOffset, index, surahCount) + 1;
    return AyahRef(surah, index - _index.surahOffset[surah - 1] + 1);
  }

  /// The ayah after [ref], null at the end of the Quran.
  static AyahRef? next(AyahRef ref) {
    final i = indexOf(ref);
    return i + 1 < ayahCount ? fromIndex(i + 1) : null;
  }

  /// The ayah before [ref], null at the beginning of the Quran.
  static AyahRef? previous(AyahRef ref) {
    final i = indexOf(ref);
    return i > 0 ? fromIndex(i - 1) : null;
  }

  /// The largest `i < count` with `starts[i] <= value` (starts is ascending and
  /// starts at 0).
  static int _lastAtOrBefore(List<int> starts, int value, int count) {
    var low = 0;
    var high = count - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (starts[mid] <= value) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }

  // -- juz and hizb --------------------------------------------------------

  /// The juz (1 to 30) a hizb belongs to: two hizb per juz.
  static int juzOfHizb(int hizb) {
    RangeError.checkValueInInterval(hizb, 1, hizbCount, 'hizb');
    return (hizb + 1) ~/ 2;
  }

  /// 1 or 2: which half of its juz a hizb is.
  static int halfOfJuz(int hizb) {
    RangeError.checkValueInInterval(hizb, 1, hizbCount, 'hizb');
    return hizb.isOdd ? 1 : 2;
  }

  /// The juz that holds [ref].
  static int juzOf(AyahRef ref) =>
      _lastAtOrBefore(_index.juzStart, indexOf(ref), juzCount) + 1;

  /// The hizb that holds [ref].
  static int hizbOf(AyahRef ref) =>
      _lastAtOrBefore(_index.hizbStart, indexOf(ref), hizbCount) + 1;

  /// The first ayah of juz [juz].
  static AyahRef juzStart(int juz) {
    RangeError.checkValueInInterval(juz, 1, juzCount, 'juz');
    return fromIndex(_index.juzStart[juz - 1]);
  }

  /// The last ayah of juz [juz].
  static AyahRef juzEnd(int juz) {
    RangeError.checkValueInInterval(juz, 1, juzCount, 'juz');
    final end = juz == juzCount ? ayahCount : _index.juzStart[juz];
    return fromIndex(end - 1);
  }

  static AyahRange juzRange(int juz) => AyahRange(juzStart(juz), juzEnd(juz));

  /// The first ayah of hizb [hizb].
  static AyahRef hizbStart(int hizb) {
    RangeError.checkValueInInterval(hizb, 1, hizbCount, 'hizb');
    return fromIndex(_index.hizbStart[hizb - 1]);
  }

  /// The last ayah of hizb [hizb].
  static AyahRef hizbEnd(int hizb) {
    RangeError.checkValueInInterval(hizb, 1, hizbCount, 'hizb');
    final end = hizb == hizbCount ? ayahCount : _index.hizbStart[hizb];
    return fromIndex(end - 1);
  }

  static AyahRange hizbRange(int hizb) =>
      AyahRange(hizbStart(hizb), hizbEnd(hizb));

  // -- surah ---------------------------------------------------------------

  static AyahRange surahRange(int surah) =>
      AyahRange(AyahRef(surah, 1), AyahRef(surah, ayahCountOf(surah)));

  /// The whole Quran, 1:1 to 114:6.
  static AyahRange get quranRange =>
      AyahRange(const AyahRef(1, 1), const AyahRef(114, 6));

  /// The surahs a range touches, in order (a juz often starts in one surah and
  /// ends in another).
  static List<int> surahsOf(AyahRange range) => [
    for (var s = range.first.surah; s <= range.last.surah; s++) s,
  ];

  // -- ruku ----------------------------------------------------------------

  /// The ruku that holds [ref].
  static Ruku rukuOf(AyahRef ref) {
    final i = _lastAtOrBefore(_index.rukuStart, indexOf(ref), rukuCount);
    return _index.rukus[i];
  }

  /// The rukus of [surah], in order (Al-Baqarah has 40).
  static List<Ruku> rukusOfSurah(int surah) {
    RangeError.checkValueInInterval(surah, 1, surahCount, 'surah');
    final first = _index.firstRukuOfSurah[surah - 1];
    final count = _index.rukuCountOfSurah[surah - 1];
    return _index.rukus.sublist(first, first + count);
  }

  /// Ruku [number] of [surah] (1 to the surah's count).
  static Ruku ruku(int surah, int number) {
    final all = rukusOfSurah(surah);
    RangeError.checkValueInInterval(number, 1, all.length, 'ruku');
    return all[number - 1];
  }

  /// How many rukus begin inside [range].
  static int rukusStartingIn(AyahRange range) {
    final low = range.first.index;
    final high = range.last.index;
    var count = 0;
    for (final start in _index.rukuStart) {
      if (start > high) break;
      if (start >= low) count++;
    }
    return count;
  }

  // -- all at once ---------------------------------------------------------

  /// Where [ref] is in the juz, the hizb and the ruku.
  static DivisionPosition positionOf(AyahRef ref) => DivisionPosition(
    ayah: ref,
    juz: juzOf(ref),
    hizb: hizbOf(ref),
    ruku: rukuOf(ref),
  );

  /// What begins at [ref] (see [DivisionStarts]).
  static DivisionStarts startsAt(AyahRef ref) {
    final i = indexOf(ref);
    final ruku = _index.rukuAt[i];
    return DivisionStarts(
      ayah: ref,
      surahStart: ref.ayah == 1,
      juz: _index.juzAt[i],
      hizb: _index.hizbAt[i],
      ruku: ruku == null ? null : _index.rukus[ruku],
    );
  }

  /// The ayahs of the [unit] that holds [at].
  static AyahRange rangeOf(DivisionUnit unit, AyahRef at) => switch (unit) {
    DivisionUnit.surah => surahRange(at.surah),
    DivisionUnit.juz => juzRange(juzOf(at)),
    DivisionUnit.hizb => hizbRange(hizbOf(at)),
    DivisionUnit.ruku => rukuOf(at).range,
  };
}

/// The tables of [QuranDivisionsData] turned into places among the ayahs.
final class _Index {
  _Index._({
    required this.surahOffset,
    required this.juzStart,
    required this.hizbStart,
    required this.rukuStart,
    required this.rukus,
    required this.firstRukuOfSurah,
    required this.rukuCountOfSurah,
    required this.juzAt,
    required this.hizbAt,
    required this.rukuAt,
  });

  /// For surah s (from 1) the number of ayahs before it: `surahOffset[s - 1]`.
  final List<int> surahOffset;

  /// The place of the first ayah of each juz, hizb and ruku.
  final List<int> juzStart;
  final List<int> hizbStart;
  final List<int> rukuStart;

  final List<Ruku> rukus;

  /// Per surah (from 1): where its first ruku is in [rukus], and how many it
  /// has.
  final List<int> firstRukuOfSurah;
  final List<int> rukuCountOfSurah;

  /// Place of an ayah to the juz, hizb or index in [rukus] that begins there.
  final Map<int, int> juzAt;
  final Map<int, int> hizbAt;
  final Map<int, int> rukuAt;

  static _Index build() {
    final counts = QuranDivisionsData.surahAyahCounts;
    final offsets = List<int>.filled(QuranDivisions.surahCount, 0);
    var total = 0;
    for (var s = 0; s < QuranDivisions.surahCount; s++) {
      offsets[s] = total;
      total += counts[s];
    }

    int place(String key) {
      final parts = key.split(':');
      return offsets[int.parse(parts[0]) - 1] + int.parse(parts[1]) - 1;
    }

    AyahRef refOf(int surah, int place) =>
        AyahRef(surah, place - offsets[surah - 1] + 1);

    final juzStart = [for (final k in QuranDivisionsData.juzStarts) place(k)];
    final hizbStart = [for (final k in QuranDivisionsData.hizbStarts) place(k)];
    final rukuStart = [for (final k in QuranDivisionsData.rukuStarts) place(k)];

    // The surah of each ruku start, then the numbering inside the surah.
    final surahOfRuku = <int>[];
    for (final key in QuranDivisionsData.rukuStarts) {
      surahOfRuku.add(int.parse(key.split(':').first));
    }
    final firstRuku = List<int>.filled(QuranDivisions.surahCount, 0);
    final rukuCount = List<int>.filled(QuranDivisions.surahCount, 0);
    for (var i = 0; i < surahOfRuku.length; i++) {
      final s = surahOfRuku[i] - 1;
      if (rukuCount[s] == 0) firstRuku[s] = i;
      rukuCount[s]++;
    }

    final rukus = <Ruku>[];
    for (var i = 0; i < rukuStart.length; i++) {
      final surah = surahOfRuku[i];
      final lastPlace = i + 1 < rukuStart.length && surahOfRuku[i + 1] == surah
          ? rukuStart[i + 1] - 1
          : offsets[surah - 1] + counts[surah - 1] - 1;
      rukus.add(
        Ruku(
          surah: surah,
          number: i - firstRuku[surah - 1] + 1,
          count: rukuCount[surah - 1],
          first: refOf(surah, rukuStart[i]),
          last: refOf(surah, lastPlace),
        ),
      );
    }

    return _Index._(
      surahOffset: List.unmodifiable(offsets),
      juzStart: List.unmodifiable(juzStart),
      hizbStart: List.unmodifiable(hizbStart),
      rukuStart: List.unmodifiable(rukuStart),
      rukus: List.unmodifiable(rukus),
      firstRukuOfSurah: List.unmodifiable(firstRuku),
      rukuCountOfSurah: List.unmodifiable(rukuCount),
      juzAt: Map.unmodifiable({
        for (var i = 0; i < juzStart.length; i++) juzStart[i]: i + 1,
      }),
      hizbAt: Map.unmodifiable({
        for (var i = 0; i < hizbStart.length; i++) hizbStart[i]: i + 1,
      }),
      rukuAt: Map.unmodifiable({
        for (var i = 0; i < rukuStart.length; i++) rukuStart[i]: i,
      }),
    );
  }
}
