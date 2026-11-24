import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/span.dart';

enum RangeInputProblem { empty, unrecognised, outOfRange, backwards }

/// What [RangeInput.parse] made of a text: a [span] or a [problem].
final class RangeInputResult {
  const RangeInputResult.ok(Span this.span) : problem = null;
  const RangeInputResult.fail(RangeInputProblem this.problem) : span = null;

  final Span? span;
  final RangeInputProblem? problem;

  bool get isOk => span != null;
}

/// Reads what the user types for "what did I do": a page ("12", "p 12",
/// "p 12-15"), a piece of any partition by its short word ("ch 3", "ch 3-5",
/// "s 2", "j 30", "hz 7") or ayahs ("2:255", "2:255-260", "2:280-3:5").
/// Everything becomes a [Span]; the short words are those of the partitions
/// passed in, so the user's own partitions work the same as the natural ones.
/// Pure Dart.
abstract final class RangeInput {
  static final RegExp _ayah = RegExp(
    r'^(\d{1,3})\s*:\s*(\d{1,3})(?:\s*[-\u2013]\s*(?:(\d{1,3})\s*:\s*)?(\d{1,3}))?$',
  );
  static final RegExp _unit = RegExp(
    r'^([a-z]*)\s*(\d{1,4})(?:\s*[-\u2013]\s*(\d{1,4}))?$',
  );

  static const Map<String, String> _alias = {
    'page': 'p',
    'pg': 'p',
    'surah': 's',
    'sura': 's',
    'juz': 'j',
    'hizb': 'hz',
    'ruku': 'ru',
  };

  static RangeInputResult parse(String text, List<Partition> partitions) {
    final input = text.trim().toLowerCase();
    if (input.isEmpty) return const RangeInputResult.fail(RangeInputProblem.empty);

    final ayah = _ayah.firstMatch(input);
    if (ayah != null) {
      final from = AyahRef(int.parse(ayah.group(1)!), int.parse(ayah.group(2)!));
      final toSurah = ayah.group(3) == null ? from.surah : int.parse(ayah.group(3)!);
      final toAyah = ayah.group(4) == null ? from.ayah : int.parse(ayah.group(4)!);
      final to = AyahRef(toSurah, toAyah);
      if (!from.isValid || !to.isValid) {
        return const RangeInputResult.fail(RangeInputProblem.outOfRange);
      }
      if (to.index < from.index) {
        return const RangeInputResult.fail(RangeInputProblem.backwards);
      }
      return RangeInputResult.ok(Span(from.index, to.index));
    }

    final unit = _unit.firstMatch(input);
    if (unit == null) {
      return const RangeInputResult.fail(RangeInputProblem.unrecognised);
    }
    var word = unit.group(1)!;
    word = _alias[word] ?? word;
    final partition = _find(word, partitions);
    if (partition == null) {
      return const RangeInputResult.fail(RangeInputProblem.unrecognised);
    }
    final from = int.parse(unit.group(2)!);
    final to = unit.group(3) == null ? from : int.parse(unit.group(3)!);
    if (from < 1 || to < 1 || from > partition.count || to > partition.count) {
      return const RangeInputResult.fail(RangeInputProblem.outOfRange);
    }
    if (to < from) {
      return const RangeInputResult.fail(RangeInputProblem.backwards);
    }
    return RangeInputResult.ok(
      Span(partition.spanOf(from).first, partition.spanOf(to).last),
    );
  }

  /// The partition a short word names: a bare number means pages; the user's
  /// own partitions win over a natural one with the same word.
  static Partition? _find(String word, List<Partition> partitions) {
    if (word.isEmpty) {
      for (final p in partitions) {
        if (p.kind == PartitionKind.page) return p;
      }
      return null;
    }
    for (final p in partitions) {
      if (p.isCustom && (p.unit.toLowerCase() == word || p.id.toLowerCase() == word)) {
        return p;
      }
    }
    for (final p in partitions) {
      if (!p.isCustom && (p.unit.toLowerCase() == word || p.id.toLowerCase() == word)) {
        return p;
      }
    }
    return null;
  }
}
