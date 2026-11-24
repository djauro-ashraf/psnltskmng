import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/memo/data/default_ch_data.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/span.dart';

enum PartitionKind { surah, juz, hizb, ruku, page, custom }

/// One piece of a [Partition]: its number (1-based) and the ayahs it holds.
final class Segment {
  const Segment(this.number, this.span);

  final int number;
  final Span span;
}

/// A way of cutting the Quran into consecutive pieces. The cuts are ayah
/// places, so the pieces never overlap and never share anything; a page that a
/// cut falls in the middle of simply shows up in two pieces.
///
/// The natural cuts (surah, juz, hizb, ruku, page) are built from the
/// reference data. The user's own partitions ([PartitionKind.custom], the
/// default one being the original ch) are stored and can be edited at any time:
/// no memorisation data refers to a partition, so changing one changes nothing
/// but the way things are grouped. Pure Dart.
final class Partition {
  Partition({
    required this.id,
    required this.name,
    required this.unit,
    required this.kind,
    required Iterable<int> starts,
    this.exact = true,
  }) : starts = List.unmodifiable(cleanStarts(starts));

  /// "ch", "surah", "page"...: how input and settings name it.
  final String id;

  /// What the screens call it ("My ch", "Surah").
  final String name;

  /// The short word before a number ("ch 3", "s 5", "p 12").
  final String unit;

  final PartitionKind kind;

  /// Where each piece begins, strictly increasing, the first being 0.
  final List<int> starts;

  /// False for a page partition made from the standard print while another one
  /// is chosen.
  final bool exact;

  bool get isCustom => kind == PartitionKind.custom;

  /// How many pieces.
  int get count => starts.length;

  /// The ayahs of piece [number] (1 to [count]).
  Span spanOf(int number) {
    RangeError.checkValueInInterval(number, 1, count, 'number');
    final first = starts[number - 1];
    final last = number == count ? Span.quran.last : starts[number] - 1;
    return Span(first, last);
  }

  Segment segment(int number) => Segment(number, spanOf(number));

  List<Segment> get segments => [
    for (var n = 1; n <= count; n++) segment(n),
  ];

  /// The number of the piece that holds [place].
  int numberAt(int place) {
    var low = 0;
    var high = count - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (starts[mid] <= place) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low + 1;
  }

  /// The pieces that [span] touches, in order.
  List<Segment> segmentsTouching(Span span) {
    final result = <Segment>[];
    for (var n = numberAt(span.first); n <= count; n++) {
      final piece = spanOf(n);
      if (piece.first > span.last) break;
      result.add(Segment(n, piece));
    }
    return result;
  }

  /// "ch 3".
  String labelOf(int number) => '$unit $number';

  /// Sorted, without duplicates, always beginning at 0 (the first piece starts
  /// at the beginning of the Quran); places outside the book are dropped.
  static List<int> cleanStarts(Iterable<int> raw) {
    final set = <int>{0};
    for (final place in raw) {
      if (place >= 0 && place <= Span.quran.last) set.add(place);
    }
    return set.toList()..sort();
  }

  Partition copyWith({String? name, String? unit, Iterable<int>? starts}) =>
      Partition(
        id: id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        kind: kind,
        starts: starts ?? this.starts,
        exact: exact,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'unit': unit,
    'starts': starts,
  };

  /// A custom partition from what [toJson] wrote; null when unusable.
  static Partition? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final unit = json['unit'];
    final raw = json['starts'];
    if (id is! String || id.isEmpty || name is! String || raw is! List) {
      return null;
    }
    return Partition(
      id: id,
      name: name,
      unit: unit is String && unit.trim().isNotEmpty ? unit.trim() : 'ch',
      kind: PartitionKind.custom,
      starts: [for (final v in raw) if (v is int) v],
    );
  }

  /// The user's original ch, as ayah cuts (71 pieces).
  static Partition originalCh() => Partition(
    id: 'ch',
    name: 'ch',
    unit: 'ch',
    kind: PartitionKind.custom,
    starts: [for (final key in DefaultChData.starts) AyahRef.tryParse(key)!.index],
  );
}

/// The natural partitions, built from the reference data.
abstract final class NaturalPartitions {
  static Partition surah() => Partition(
    id: 'surah',
    name: 'Surah',
    unit: 's',
    kind: PartitionKind.surah,
    starts: [
      for (var s = 1; s <= QuranDivisions.surahCount; s++)
        QuranDivisions.indexOf(AyahRef(s, 1)),
    ],
  );

  static Partition juz() => Partition(
    id: 'juz',
    name: 'Juz',
    unit: 'j',
    kind: PartitionKind.juz,
    starts: [
      for (var j = 1; j <= QuranDivisions.juzCount; j++)
        QuranDivisions.juzStart(j).index,
    ],
  );

  static Partition hizb() => Partition(
    id: 'hizb',
    name: 'Hizb',
    unit: 'hz',
    kind: PartitionKind.hizb,
    starts: [
      for (var h = 1; h <= QuranDivisions.hizbCount; h++)
        QuranDivisions.hizbStart(h).index,
    ],
  );

  static Partition ruku() => Partition(
    id: 'ruku',
    name: 'Ruku',
    unit: 'ru',
    kind: PartitionKind.ruku,
    starts: [
      for (var s = 1; s <= QuranDivisions.surahCount; s++)
        for (final r in QuranDivisions.rukusOfSurah(s)) r.first.index,
    ],
  );

  static Partition page(PageMap map) => Partition(
    id: 'page',
    name: 'Page',
    unit: 'p',
    kind: PartitionKind.page,
    starts: map.starts,
    exact: map.exact,
  );

  /// All of them, in the order the pickers list them.
  static List<Partition> all(PageMap map) => [
    surah(),
    juz(),
    hizb(),
    ruku(),
    page(map),
  ];
}
