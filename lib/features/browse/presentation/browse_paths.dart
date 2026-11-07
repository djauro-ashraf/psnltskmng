import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';

/// Locations of the browse routes. The tab root hosts the ps / ss / ch / juz
/// lists; everything below it is a detail screen:
///
/// ```
/// INFO (what a tap on a row opens with Info chosen)
/// /browse/ps/:page                       p
/// /browse/ss/:s                          s            -> more details
/// /browse/ss/:s/ch                       its ch       (s spanning several ch)
/// /browse/ss/:s/ch/:ch                   the s in that ch -> more details
/// /browse/ss/:s/ch/:ch/ps[/:page]        its pages
/// /browse/ss/:s/ps[/:page]               its pages    (s with a single ch)
/// /browse/ch/:ch                         ch           -> more details
/// /browse/ch/:ch/ss                      its s        (ch touching several s)
/// /browse/ch/:ch/ss/:s                   the ch in that s -> more details
/// /browse/ch/:ch/ss/:s/ps[/:page]        its pages
/// /browse/ch/:ch/ps[/:page]              its pages    (ch with a single s)
/// /browse/juz/:juz                       juz          -> more details
/// /browse/juz/:juz/ps[/:page]            its pages
///
/// INFO ONLY (opened from the reader: no switch, no "more details"; Back
/// returns to the reading spot)
/// /browse/info/ps/:page
/// /browse/info/ss/:s
/// /browse/info/ss/:s/ch/:ch
/// /browse/info/ch/:ch
/// /browse/info/juz/:juz
///
/// READING (what a tap opens with Quran chosen; one screen, see `ReaderPage`)
/// /browse/read/p/:page                   that page
/// /browse/read/s/:s                      the first page of the s, unit Surah
/// /browse/read/ch/:ch                    the first page of the ch, unit ch
/// /browse/read/juz/:juz                  the first page of the juz, unit Juz
/// /browse/read/part/:s/:ch               an s inside a ch, limited to its pages
/// /browse/read/a/:s/:a[?view=words]      an ayah (Continue reading)
/// /browse/read/range/:from/:to           pages (the range Today revises)
/// /browse/tafsir/:s/:a                   the tafsir of an ayah (full screen)
/// ```
///
/// Routes carry ids only.
abstract final class BrowsePaths {
  static const String root = AppRoutes.browse;
  static const String ps = '$root/ps';
  static const String ss = '$root/ss';
  static const String ch = '$root/ch';
  static const String juz = '$root/juz';
  static const String info = '$root/info';
  static const String read = '$root/read';
  static const String tafsir = '$root/tafsir';
  static const String ask = '$root/ask';

  static String readPage(int page) => '$read/p/$page';
  static String readSurah(int s) => '$read/s/$s';
  static String readCh(int ch) => '$read/ch/$ch';
  static String readJuz(int juz) => '$read/juz/$juz';
  static String readPart(int s, int ch) => '$read/part/$s/$ch';
  static String readRange(int from, int to) => '$read/range/$from/$to';

  /// An ayah; [view] is the view of the last time (Continue reading).
  static String readAyah(AyahRef ayah, {QuranView? view}) =>
      '$read/a/${ayah.surah}/${ayah.ayah}'
      '${view == null ? '' : '?view=${view.name}'}';

  static String tafsirOf(AyahRef ayah) =>
      '$tafsir/${ayah.surah}/${ayah.ayah}';

  static String askNew({AyahRef? ayah, String? prompt, String? focus}) {
    final params = <String, String>{};
    if (ayah != null) params['ayah'] = ayah.key;
    if (prompt != null) params['prompt'] = prompt;
    if (focus != null) params['focus'] = focus;
    if (params.isEmpty) return '$ask/new';
    final query = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return '$ask/new?$query';
  }

  static String askChat(String id) => '$ask/$id';

  static final RegExp _pageScreen = RegExp(
    '^${RegExp.escape(root)}/(?:.*/)?ps/\\d+/?\$',
  );

  /// True for the location of a page screen (`.../ps/:page`), false for
  /// everything else, the list of pages (`.../ps`) included.
  static bool isPageScreen(String location) => _pageScreen.hasMatch(location);

  static final RegExp _scopeScreen = RegExp(
    '^${RegExp.escape(root)}/'
    '(?:ss/\\d+(?:/ch/\\d+)?|ch/\\d+(?:/ss/\\d+)?|juz/\\d+)/?\$',
  );

  /// True for the location of the screen of an s, a ch, a juz or a part
  /// (`/ss/:s`, `/ss/:s/ch/:ch`, `/ch/:ch`, `/ch/:ch/ss/:s`, `/juz/:juz`),
  /// false for their lists (`.../ch`, `.../ss`, `.../ps`).
  static bool isScopeScreen(String location) => _scopeScreen.hasMatch(location);

  static final RegExp _readingScreen = RegExp(
    '^${RegExp.escape(read)}/|^${RegExp.escape(tafsir)}/|^${RegExp.escape(ask)}',
  );

  /// The reader and the tafsir screen are for reading: on a phone the bottom
  /// bar steps aside there, and the way out is the back button of their line.
  static bool isReadingScreen(String location) =>
      _readingScreen.hasMatch(location);
}
