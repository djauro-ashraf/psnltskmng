import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';

void main() {
  group('BrowsePaths.isPageScreen', () {
    test('is true for the screen of a page, wherever it is reached from', () {
      for (final path in [
        '/browse/ps/1',
        '/browse/ps/604',
        '/browse/ss/2/ps/48',
        '/browse/ss/2/ch/3/ps/48',
        '/browse/ch/7/ps/120',
        '/browse/ch/7/ss/5/ps/120/',
        '/browse/juz/15/ps/282',
        '/browse/info/ps/12',
      ]) {
        expect(BrowsePaths.isPageScreen(path), isTrue, reason: path);
      }
    });

    test('is false for everything else', () {
      for (final path in [
        '/browse',
        '/browse/ps',
        '/browse/ss/2',
        '/browse/ss/2/ps',
        '/browse/ch/7/ss',
        '/browse/juz/15/ps',
        '/browse/ps/abc',
        '/today',
        '/settings',
        '/overview',
        '/ps/12',
      ]) {
        expect(BrowsePaths.isPageScreen(path), isFalse, reason: path);
      }
    });
  });

  group('BrowsePaths.isScopeScreen', () {
    test('is true for the screen of an s, a ch, a juz or a part', () {
      for (final path in [
        '/browse/ss/5',
        '/browse/ss/5/',
        '/browse/ss/5/ch/14',
        '/browse/ch/13',
        '/browse/ch/13/ss/4',
        '/browse/juz/15',
        '/browse/juz/15/',
      ]) {
        expect(BrowsePaths.isScopeScreen(path), isTrue, reason: path);
      }
    });

    test('is false for their lists, their pages and the rest', () {
      for (final path in [
        '/browse',
        '/browse/ss/5/ch',
        '/browse/ss/5/ps',
        '/browse/ss/5/ch/14/ps',
        '/browse/ss/5/ps/106',
        '/browse/ch/13/ss',
        '/browse/ch/13/ps',
        '/browse/juz',
        '/browse/juz/15/ps',
        '/browse/juz/x',
        '/browse/ps/12',
        '/browse/ss/x',
        '/browse/read/s/5',
        '/today',
      ]) {
        expect(BrowsePaths.isScopeScreen(path), isFalse, reason: path);
      }
    });
  });

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

    test('is false for the lists and every info screen (the bar stays)', () {
      for (final path in [
        '/browse',
        '/browse/ps',
        '/browse/ps/12',
        '/browse/ss/5',
        '/browse/ss/5/ps/106',
        '/browse/ch/13/ss/4',
        '/browse/juz/3',
        '/browse/info/ps/12',
        '/browse/info/ss/5',
        '/today',
        '/overview',
      ]) {
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

    test('the info-only locations sit under /browse/info', () {
      expect(BrowsePaths.info, '/browse/info');
      expect('${BrowsePaths.info}/ps/12', '/browse/info/ps/12');
      expect(BrowsePaths.juz, '/browse/juz');
      expect(BrowsePaths.read, '/browse/read');
      expect(BrowsePaths.tafsir, '/browse/tafsir');
    });
  });
}
