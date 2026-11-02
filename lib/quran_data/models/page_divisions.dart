import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/context_line.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

/// What the divisions say about one page of the chosen print: its juz and hizb
/// (`Juz 15 · Hizb 29`, or `Juz 3 → 4` when it changes on the page) and the
/// rukus that BEGIN on it. For the page info card. Pure Dart; the layout is
/// asked of the [PageLocator].
final class PageDivisions {
  const PageDivisions({required this.line, required this.rukus});

  /// The line of the first and the last ayah of the page.
  final ContextLine line;

  /// The rukus that begin on the page (their first ayah starts on it), in the
  /// order of the text; often none, rarely more than two.
  final List<Ruku> rukus;

  /// `Juz 15 · Hizb 29`.
  String get juzHizbText => '${line.juzText} · ${line.hizbText}';

  /// Null when the layout of the print is not downloaded.
  static Future<PageDivisions?> of(int page, PageLocator locator) async {
    final first = await locator.firstAyahOf(page);
    final last = await locator.lastAyahOf(page);
    if (first == null || last == null) return null;
    final rukus = <Ruku>[];
    final starting = await WordsStream.firstStartingOn(page, locator);
    if (starting != null && starting <= last) {
      var ayah = starting;
      while (true) {
        final ruku = QuranDivisions.startsAt(ayah).ruku;
        if (ruku != null) rukus.add(ruku);
        if (ayah == last) break;
        final next = QuranDivisions.next(ayah);
        if (next == null) break;
        ayah = next;
      }
    }
    return PageDivisions(
      line: ContextLine.span(first, last),
      rukus: List<Ruku>.unmodifiable(rukus),
    );
  }
}
