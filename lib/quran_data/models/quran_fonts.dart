import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';

/// The font packs. They are not in the manifest: the fonts come straight from
/// Quran Foundation's font server, which the Developer Terms allow an app to
/// cache (with the credit shown in Quran data).
abstract final class QuranFonts {
  static const String _base = 'https://verses.quran.foundation/fonts/quran/hafs';

  /// The Unicode font of the banner, the basmallah and the Words view.
  static const String textFontFile = 'UthmanicHafs1Ver18.ttf';

  /// Where the Unicode font is kept.
  static const String textFontPath = 'fonts/$textFontFile';

  static const String textFontId = 'font-text';

  /// The 604 page fonts of [edition]. One pack per edition, so the one the
  /// reader does not use is never downloaded.
  static QuranPack pageFonts(MushafEdition edition) => QuranPack(
    id: edition.fontsPackId,
    kind: QuranPackKind.fonts,
    title: 'Page fonts',
    files: [
      for (var page = 1; page <= MushafPage.pageCount; page++)
        PackFile(
          path: edition.fontPath(page),
          url: Uri.parse('$_base/${edition.name}/ttf/p$page.ttf'),
        ),
    ],
  );

  /// The Unicode Arabic font.
  static QuranPack textFont() => QuranPack(
    id: textFontId,
    kind: QuranPackKind.textFont,
    title: 'Arabic text font',
    files: [
      PackFile(
        path: textFontPath,
        url: Uri.parse('$_base/uthmanic_hafs/$textFontFile'),
      ),
    ],
  );
}
