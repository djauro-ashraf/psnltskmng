import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';
import 'package:personaltskmng/quran_data/models/reader_entry.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

/// What a route asks the reader to open. Routes carry ids only (a page, an s, a
/// ch, a juz, an ayah); this is what the id means, and [ReaderResolver] turns it
/// into the page to start on, the ayah, the unit and the limit.
sealed class ReaderRequest {
  const ReaderRequest();
}

/// A page row, or a page of a list of pages: that page, Words unit Page.
final class ReadPage extends ReaderRequest {
  const ReadPage(this.page);

  final int page;
}

/// A row of the s list: the first page of the s, Words unit Surah.
final class ReadSurah extends ReaderRequest {
  const ReadSurah(this.surah);

  final int surah;
}

/// A row of the ch list: the first page of the ch, Words unit ch.
final class ReadCh extends ReaderRequest {
  const ReadCh(this.ch);

  final int ch;
}

/// A row of the juz list: the first page of the juz, Words unit Juz.
final class ReadJuz extends ReaderRequest {
  const ReadJuz(this.juz);

  final int juz;
}

/// A part (an s inside a ch): the first page of the part, Words unit Page,
/// limited to its pages.
final class ReadPart extends ReaderRequest {
  const ReadPart(this.surah, this.ch);

  final int surah;
  final int ch;
}

/// An ayah: the Continue row of Browse (the view of the last time is kept), or
/// any other link to a place. No limit.
final class ReadAyah extends ReaderRequest {
  const ReadAyah(this.ayah, {this.view});

  final AyahRef ayah;
  final QuranView? view;
}

/// A run of pages given from outside (the range Today is about to revise): the
/// reader opens on its first page, limited to the run, Words unit Page.
final class ReadRange extends ReaderRequest {
  const ReadRange(this.firstPage, this.lastPage);

  final int firstPage;
  final int lastPage;
}

/// Turns a [ReaderRequest] into a [ReaderEntry]. Pure Dart; the layout of the
/// chosen print is asked of the [PageLocator].
///
/// - The pages of an s and of a juz are looked up in the layout pack of the
///   chosen print (the two prints differ on 36 pages). For an s the table of the
///   app (`STable`) is the fallback when the layout is not downloaded, so the
///   reader still opens (it then says the pages are missing).
/// - A ch, a part and a range are given in the pages of the planner's tables
///   (the 1405 print). Under V2 they are used as they are (a page number is the
///   page number), and the ch unit of Words is replaced by Page, because the ch
///   are not defined in the 1421 print. See the reader options.
abstract final class ReaderResolver {
  /// The entry for [request]; null when the request names something that does
  /// not exist (an s 115, a ch 72, a juz 0, a pair the ch table does not list).
  static Future<ReaderEntry?> resolve(
    ReaderRequest request,
    PageLocator locator, {
    required bool v2,
  }) async {
    switch (request) {
      case ReadPage(:final page):
        if (page < 1 || page > ChTable.totalPages) return null;
        return ReaderEntry(
          page: page,
          at: await WordsStream.firstStartingOn(page, locator),
          unit: WordsUnit.page,
        );

      case ReadSurah(:final surah):
        if (surah < 1 || surah > QuranDivisions.surahCount) return null;
        final first = AyahRef(surah, 1);
        final firstPage =
            await locator.pageOf(first) ?? STable.firstPageOf(surah);
        final lastPage =
            await locator.lastPageOf(
              AyahRef(surah, QuranDivisions.ayahCountOf(surah)),
            ) ??
            STable.lastPageOf(surah);
        return ReaderEntry(
          page: firstPage,
          at: first,
          unit: WordsUnit.surah,
          limit: ReaderLimit(
            kind: ReaderLimitKind.surah,
            number: surah,
            firstPage: firstPage,
            lastPage: lastPage < firstPage ? firstPage : lastPage,
          ),
        );

      case ReadCh(:final ch):
        if (ch < 1 || ch > ChTable.chCount) return null;
        final range = ChTable.instance.displayRange(ch);
        final firstOfCh = range.start;
        final lastOfCh = range.end;
        final owned = ChTable.instance.ownedPagesOf(ch);
        // A ch that starts on a page it shares with the one before opens on
        // that page in Mushaf, and on the first ayah that is its own in Words.
        final at = await WordsStream.firstStartingOn(
          owned.isEmpty ? firstOfCh : owned.first,
          locator,
        );
        return ReaderEntry(
          page: firstOfCh,
          at: at,
          unit: v2 ? WordsUnit.page : WordsUnit.ch,
          limit: ReaderLimit(
            kind: ReaderLimitKind.ch,
            number: ch,
            firstPage: firstOfCh,
            lastPage: lastOfCh,
          ),
        );

      case ReadJuz(:final juz):
        if (juz < 1 || juz > QuranDivisions.juzCount) return null;
        final start = QuranDivisions.juzStart(juz);
        final firstPage = await locator.pageOf(start);
        final lastPage = await locator.lastPageOf(QuranDivisions.juzEnd(juz));
        return ReaderEntry(
          page: firstPage ?? 1,
          at: start,
          unit: WordsUnit.juz,
          // Without the layout the pages of the juz are not known: no limit.
          limit: firstPage == null || lastPage == null
              ? null
              : ReaderLimit(
                  kind: ReaderLimitKind.juz,
                  number: juz,
                  firstPage: firstPage,
                  lastPage: lastPage < firstPage ? firstPage : lastPage,
                ),
        );

      case ReadPart(:final surah, :final ch):
        final part = BrowseIndex.instance.part(surah, ch);
        if (part == null) return null;
        final top = await WordsStream.firstStartingOn(part.firstPage, locator);
        return ReaderEntry(
          page: part.firstPage,
          // The first page can begin with the end of the s before.
          at: top == null || top.surah != surah ? AyahRef(surah, 1) : top,
          unit: WordsUnit.page,
          limit: ReaderLimit(
            kind: ReaderLimitKind.part,
            number: ch,
            surah: surah,
            firstPage: part.firstPage,
            lastPage: part.lastPage,
            ayahs: await WordsStream.startingOnPages(
              part.firstPage,
              part.lastPage,
              locator,
            ),
          ),
        );

      case ReadAyah(:final ayah, :final view):
        if (!ayah.isValid) return null;
        return ReaderEntry(
          page: await locator.pageOf(ayah) ?? 1,
          at: ayah,
          view: view,
        );

      case ReadRange(:final firstPage, :final lastPage):
        if (firstPage < 1 ||
            lastPage > ChTable.totalPages ||
            firstPage > lastPage) {
          return null;
        }
        return ReaderEntry(
          page: firstPage,
          at: await WordsStream.firstStartingOn(firstPage, locator),
          unit: WordsUnit.page,
          limit: ReaderLimit(
            kind: ReaderLimitKind.range,
            number: 0,
            firstPage: firstPage,
            lastPage: lastPage,
            ayahs: await WordsStream.startingOnPages(
              firstPage,
              lastPage,
              locator,
            ),
          ),
        );
    }
  }
}
