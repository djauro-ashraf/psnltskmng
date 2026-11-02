import 'dart:convert';
import 'dart:io';

import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';

/// `test/fixtures/quran_divisions.json` read for tests.
///
/// It is the source the divisions tables of the app were made from, so tests
/// use it as the independent answer to check the lookups against, and (its
/// `pages` section) as a stand-in for a layout pack of the 1405 print.
///
/// In that layout an ayah is listed only on the page where it STARTS: no page
/// repeats the end of the ayah of the page before. A real layout pack does
/// repeat it, which is what `customLayout` is for.
final class DivisionsFixture {
  DivisionsFixture._(this._json);

  /// Read the first time it is used (the tests run from the project folder).
  static final DivisionsFixture instance = DivisionsFixture._(
    jsonDecode(File('test/fixtures/quran_divisions.json').readAsStringSync())
        as Map<String, dynamic>,
  );

  final Map<String, dynamic> _json;

  List<Map<String, dynamic>> _list(String name) => [
    for (final item in _json[name] as List<dynamic>)
      item as Map<String, dynamic>,
  ];

  late final List<Map<String, dynamic>> juz = _list('juz');
  late final List<Map<String, dynamic>> hizb = _list('hizb');
  late final List<Map<String, dynamic>> ruku = _list('ruku');
  late final List<Map<String, dynamic>> pages = _list('pages');

  /// The ayah of a `{"ref": "2:255", ...}` node.
  static AyahRef refOf(Object? node) {
    final text = (node as Map<String, dynamic>)['ref'] as String;
    return AyahRef.tryParse(text)!;
  }

  /// Every ayah of [page], first to last (`['2:5', '2:6']`).
  List<String> versesOfPage(int page) {
    final entry = pages[page - 1];
    final first = refOf(entry['start']);
    final last = refOf(entry['end']);
    final out = <String>[];
    for (var ayah = first; ; ayah = QuranDivisions.next(ayah)!) {
      out.add(ayah.key);
      if (ayah == last) break;
    }
    return out;
  }

  /// The locator of the 1405 print as this file has it.
  PageLocator locator() => PageLocator(
    (page) async => page < 1 || page > 604 ? null : versesOfPage(page),
  );

  /// The same layout, but the way a real layout pack lists it: each page in
  /// [continued] opens with the LAST ayah of the page before (an ayah that runs
  /// over two pages is listed on both). Everything else is as in [locator].
  PageLocator locatorWithContinuations(Set<int> continued) => PageLocator(
    (page) async {
      if (page < 1 || page > 604) return null;
      final own = versesOfPage(page);
      if (page > 1 && continued.contains(page)) {
        return [versesOfPage(page - 1).last, ...own];
      }
      return own;
    },
  );

  /// The same layout with [replaced] pages swapped for the given ayahs (for a
  /// page that holds one ayah only, and the like). The result must still go
  /// forward from page to page, as a real layout does.
  PageLocator locatorWith(Map<int, List<String>> replaced) => PageLocator(
    (page) async {
      if (page < 1 || page > 604) return null;
      return replaced[page] ?? versesOfPage(page);
    },
  );
}

/// A layout written by hand, for the cases the fixture cannot show (an ayah
/// that runs over two pages, a layout that is not downloaded). A page that is
/// not in [pages] answers null, which the locator reads as "not downloaded".
PageLocator customLayout(Map<int, List<String>> pages) =>
    PageLocator((page) async => pages[page]);

/// A layout that is not downloaded at all.
PageLocator missingLayout() => PageLocator((page) async => null);
