import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

/// What the reader was entered through, and so how far it goes before it asks.
enum ReaderLimitKind {
  /// A row of the s list (or `s` in the Go to sheet).
  surah,

  /// A row of the ch list.
  ch,

  /// A row of the juz list.
  juz,

  /// A part (an s inside a ch): opens as Page, limited to its pages.
  part,

  /// A range given from outside (the range Today is about to revise).
  range,
}

/// The unit the reader was entered through. In Mushaf the swiping stays inside
/// its pages and at the last page there is a card ("End of s 2 · continue to
/// s 3") that removes the limit. In Words the next unit simply continues, except
/// for a part or a range, which end with a "Keep reading" tile.
///
/// Pure Dart. The pages are the pages of the print the reader chose.
final class ReaderLimit {
  const ReaderLimit({
    required this.kind,
    required this.number,
    required this.firstPage,
    required this.lastPage,
    this.surah,
    this.ayahs,
  }) : assert(firstPage >= 1 && firstPage <= lastPage, 'a run of pages');

  final ReaderLimitKind kind;

  /// The number of the s, the ch or the juz. For a part, the ch (the s is
  /// [surah]). Unused (0) for a range.
  final int number;

  final int firstPage;
  final int lastPage;

  /// The s of a part.
  final int? surah;

  /// The ayahs of the limit when they are known without the layout (a range).
  /// For the others, the layout gives them from the pages.
  final AyahRange? ayahs;

  /// In Words the stream stops at the end of this limit, with a "Keep reading"
  /// tile.
  bool get stopsWords =>
      kind == ReaderLimitKind.part || kind == ReaderLimitKind.range;

  bool containsPage(int page) => page >= firstPage && page <= lastPage;

  /// The number of the next unit after the limit ("continue to s 3"), null when
  /// there is none (the end of the Quran) or the limit is a part or a range.
  int? get nextNumber {
    final max = switch (kind) {
      ReaderLimitKind.surah => QuranDivisions.surahCount,
      ReaderLimitKind.ch => ChTable.chCount,
      ReaderLimitKind.juz => QuranDivisions.juzCount,
      ReaderLimitKind.part || ReaderLimitKind.range => 0,
    };
    return number > 0 && number < max ? number + 1 : null;
  }

  @override
  bool operator ==(Object other) =>
      other is ReaderLimit &&
      other.kind == kind &&
      other.number == number &&
      other.firstPage == firstPage &&
      other.lastPage == lastPage &&
      other.surah == surah &&
      other.ayahs == ayahs;

  @override
  int get hashCode =>
      Object.hash(kind, number, firstPage, lastPage, surah, ayahs);

  @override
  String toString() => 'ReaderLimit($kind $number p$firstPage-$lastPage)';
}

/// Where and how the reader opens: from a row of Browse, the Continue row, a
/// jump, or Today.
final class ReaderEntry {
  const ReaderEntry({
    required this.page,
    this.at,
    this.unit,
    this.limit,
    this.view,
  });

  /// The page the Mushaf opens on (1 to 604).
  final int page;

  /// The ayah the reader opens on, when it is known without the layout (a
  /// surah or a juz starts at a known ayah). Null: the first ayah that starts
  /// on [page].
  final AyahRef? at;

  /// The unit Words follows. Null: the one the reader used last.
  final WordsUnit? unit;

  /// What the reader was entered through; null: nothing limits it.
  final ReaderLimit? limit;

  /// The view to open in (Continue reading keeps the view of the last time).
  /// Null: the reader's own choice (Mushaf or Words).
  final QuranView? view;

  ReaderEntry copyWith({ReaderLimit? limit, bool clearLimit = false}) =>
      ReaderEntry(
        page: page,
        at: at,
        unit: unit,
        limit: clearLimit ? null : (limit ?? this.limit),
        view: view,
      );
}

/// The place the reader keeps for "Continue reading": the last ayah read, and
/// the view it was read in.
final class LastRead {
  const LastRead(this.ayah, this.view);

  final AyahRef ayah;
  final QuranView view;

  /// `2:142|words`.
  String encode() => '${ayah.key}|${view.name}';

  /// Reads what [encode] wrote; null for anything else.
  static LastRead? decode(String? text) {
    if (text == null) return null;
    final parts = text.split('|');
    if (parts.length != 2) return null;
    final ayah = AyahRef.tryParse(parts[0]);
    final view = QuranView.values.asNameMap()[parts[1]];
    if (ayah == null || view == null) return null;
    return LastRead(ayah, view);
  }

  @override
  bool operator ==(Object other) =>
      other is LastRead && other.ayah == ayah && other.view == view;

  @override
  int get hashCode => Object.hash(ayah, view);
}
