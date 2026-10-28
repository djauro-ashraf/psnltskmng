import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';

/// What loading a page gave. Never throws: a page that is not there is a
/// state the screen explains, not a crash.
sealed class MushafPageResult {
  const MushafPageResult();
}

/// The page and its font are loaded; draw the page with [fontFamily].
final class MushafReady extends MushafPageResult {
  const MushafReady(this.page, this.fontFamily);

  final MushafPage page;
  final String fontFamily;
}

/// The pages are not downloaded.
final class MushafNotInstalled extends MushafPageResult {
  const MushafNotInstalled();
}

/// The page is downloaded but its font is not.
final class MushafFontMissing extends MushafPageResult {
  const MushafFontMissing();
}

/// The page is downloaded but it could not be read.
final class MushafBroken extends MushafPageResult {
  const MushafBroken(this.message);

  final String message;
}

/// Where the mushaf pages come from (the downloaded Quran; see `quran_data`).
abstract interface class MushafSource {
  /// Loads page [page] (1 to 604) of [edition] and registers its font.
  Future<MushafPageResult> load(MushafEdition edition, int page);

  /// Registers the Unicode font used for the surah banner and the basmallah and
  /// returns its family; null when it is not installed (the platform's own
  /// Arabic font is used then).
  Future<String?> loadTextFont();
}

/// The font family of the banner, the basmallah and the Words view text.
const String mushafTextFontFamily = 'MushafHafs';

/// The source when no Quran is downloaded: every page is "not installed".
class NoMushafSource implements MushafSource {
  const NoMushafSource();

  @override
  Future<MushafPageResult> load(MushafEdition edition, int page) async =>
      const MushafNotInstalled();

  @override
  Future<String?> loadTextFont() async => null;
}
