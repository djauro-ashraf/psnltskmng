import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';

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
    test('is true for the screen of an s, a ch or a part', () {
      for (final path in [
        '/browse/ss/5',
        '/browse/ss/5/',
        '/browse/ss/5/ch/14',
        '/browse/ch/13',
        '/browse/ch/13/ss/4',
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
        '/browse/ps/12',
        '/browse/ss/x',
        '/today',
      ]) {
        expect(BrowsePaths.isScopeScreen(path), isFalse, reason: path);
      }
    });

    test('a reading screen is a page screen or a unit screen', () {
      expect(BrowsePaths.isReadingScreen('/browse/ps/12'), isTrue);
      expect(BrowsePaths.isReadingScreen('/browse/ss/5/ps/106'), isTrue);
      expect(BrowsePaths.isReadingScreen('/browse/ss/5'), isTrue);
      expect(BrowsePaths.isReadingScreen('/browse/ch/13/ss/4'), isTrue);
      expect(BrowsePaths.isReadingScreen('/browse/ss/5/ch'), isFalse);
      expect(BrowsePaths.isReadingScreen('/browse/ss/5/ps'), isFalse);
      expect(BrowsePaths.isReadingScreen('/browse'), isFalse);
    });
  });
}
