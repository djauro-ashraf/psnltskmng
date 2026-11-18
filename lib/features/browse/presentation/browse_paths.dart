import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/quran_view.dart';

/// Locations of the browse routes. The tab root hosts the Surahs / ch / Juz /
/// Pages lists; everything below it is the reader, the tafsir or the assistant:
///
/// ```
/// READING (what a tap on a row opens; one screen, see `ReaderPage`, in the way
/// to read the Details | Mushaf | Words switch says)
/// /browse/read/s/:s                      the start of the surah, unit Surah
/// /browse/read/ch/:ch                    the start of the ch, unit ch
/// /browse/read/juz/:juz                  the start of the juz, unit Juz
/// /browse/read/part/:s/:ch               a surah inside a ch, limited to its pages
/// /browse/read/p/:page                   that page
/// /browse/read/a/:s/:a[?view=words]      an ayah (Continue reading)
/// /browse/read/range/:from/:to           pages (the range Today revises)
/// /browse/tafsir/:s/:a                   the tafsir of an ayah (full screen)
/// /browse/ask[/...]                      the assistant
/// ```
///
/// The details of a surah, a juz, a ch or a page are not screens: they are the
/// Details view of the reader and the sheets it opens (`details_blocks.dart`).
///
/// Routes carry ids only.
abstract final class BrowsePaths {
  static const String root = AppRoutes.browse;
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

  static String _query(Map<String, String> params) => params.isEmpty
      ? ''
      : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';

  /// A new chat; [ayah] is attached to it, [focus] is the words the reader had
  /// selected in it, [prompt] a question put in the box and [tafsir] the tafsir
  /// the reader was reading (its id; without it the first one downloaded).
  static String askNew({
    AyahRef? ayah,
    String? prompt,
    String? focus,
    String? tafsir,
  }) =>
      '$ask/new${_query({
        'ayah': ?ayah?.key,
        if (prompt != null && prompt.isNotEmpty) 'prompt': prompt,
        if (focus != null && focus.isNotEmpty) 'focus': focus,
        if (tafsir != null && tafsir.isNotEmpty) 'tafsir': tafsir,
      })}';

  /// A chat that exists; [prompt] and [focus] go in its box (the reader asked
  /// about something and chose to go on with this chat).
  static String askChat(String id, {String? prompt, String? focus}) =>
      '$ask/$id${_query({
        'prompt': ?prompt,
        'focus': ?focus,
      })}';

  static final RegExp _readingScreen = RegExp(
    '^${RegExp.escape(read)}/|^${RegExp.escape(tafsir)}/|^${RegExp.escape(ask)}',
  );

  /// The reader and the tafsir screen are for reading: on a phone the bottom
  /// bar steps aside there, and the way out is the back button of their line.
  static bool isReadingScreen(String location) =>
      _readingScreen.hasMatch(location);
}
