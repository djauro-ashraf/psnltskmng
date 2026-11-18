import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';

void main() {
  group('BrowsePaths.isReadingScreen', () {
    test('is true for the reader and the tafsir screen', () {
      for (final path in [
        '/browse/read/p/12',
        '/browse/read/s/2',
        '/browse/read/ch/13',
        '/browse/read/juz/15',
        '/browse/read/part/5/13',
        '/browse/read/a/2/255',
        '/browse/read/a/2/255?view=words',
        '/browse/read/range/106/110',
        '/browse/tafsir/2/255',
      ]) {
        expect(BrowsePaths.isReadingScreen(path), isTrue, reason: path);
      }
    });

    test('is false for the lists and the rest (the bar stays)', () {
      for (final path in ['/browse', '/today', '/overview']) {
        expect(BrowsePaths.isReadingScreen(path), isFalse, reason: path);
      }
    });
  });

  group('the paths of the reader', () {
    test('are built from ids only', () {
      expect(BrowsePaths.readPage(106), '/browse/read/p/106');
      expect(BrowsePaths.readSurah(2), '/browse/read/s/2');
      expect(BrowsePaths.readCh(13), '/browse/read/ch/13');
      expect(BrowsePaths.readJuz(15), '/browse/read/juz/15');
      expect(BrowsePaths.readPart(5, 13), '/browse/read/part/5/13');
      expect(BrowsePaths.readRange(106, 110), '/browse/read/range/106/110');
      expect(BrowsePaths.tafsirOf(const AyahRef(2, 255)), '/browse/tafsir/2/255');
    });

    test('an ayah carries the view only when there is one', () {
      expect(
        BrowsePaths.readAyah(const AyahRef(2, 255)),
        '/browse/read/a/2/255',
      );
      expect(
        BrowsePaths.readAyah(const AyahRef(2, 255), view: QuranView.words),
        '/browse/read/a/2/255?view=words',
      );
      expect(
        BrowsePaths.readAyah(const AyahRef(2, 255), view: QuranView.mushaf),
        '/browse/read/a/2/255?view=mushaf',
      );
      expect(
        BrowsePaths.readAyah(const AyahRef(2, 255), view: QuranView.details),
        '/browse/read/a/2/255?view=details',
      );
    });

    test('every path of the reader is a reading screen', () {
      for (final path in [
        BrowsePaths.readPage(1),
        BrowsePaths.readSurah(1),
        BrowsePaths.readCh(1),
        BrowsePaths.readJuz(1),
        BrowsePaths.readPart(1, 1),
        BrowsePaths.readRange(1, 2),
        BrowsePaths.readAyah(const AyahRef(1, 1), view: QuranView.words),
        BrowsePaths.tafsirOf(const AyahRef(1, 1)),
      ]) {
        expect(BrowsePaths.isReadingScreen(path), isTrue, reason: path);
      }
    });

    test('the view of the query is read back by its name', () {
      for (final view in QuranView.values) {
        final path = BrowsePaths.readAyah(const AyahRef(2, 1), view: view);
        final uri = Uri.parse(path);
        expect(QuranView.values.asNameMap()[uri.queryParameters['view']], view);
      }
    });

    test('the reader and the tafsir sit under the tab root', () {
      expect(BrowsePaths.read, '/browse/read');
      expect(BrowsePaths.tafsir, '/browse/tafsir');
    });

    test('the details of a group are not screens: no path for them', () {
      // A surah, a juz, a ch or a page has no screen of its own any more: the
      // Details view of the reader and its sheets are where they are read.
      for (final path in [
        '/browse/ps/12',
        '/browse/ss/5',
        '/browse/ch/13',
        '/browse/juz/15',
        '/browse/info/ps/12',
      ]) {
        expect(BrowsePaths.isReadingScreen(path), isFalse, reason: path);
      }
    });
  });
}
