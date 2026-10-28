/// The two prints of the Madinah mushaf the page fonts exist for. Both have 604
/// pages, but a few pages hold different ayahs in the two.
enum MushafEdition {
  /// The 1405 print, the classic one. Its pages are the ones the app's page
  /// tables (`STable`, `ChTable`) are made for: every s starts and ends on the
  /// page the table says.
  v1,

  /// The 1421 print. 36 pages hold different ayahs than in [v1] (a few in juz
  /// 30 end a page later), so a page number can mean other ayahs than in the
  /// planner's tables.
  v2;

  /// The edition the app opens with.
  static const MushafEdition standard = MushafEdition.v1;

  /// 1 or 2.
  int get number => index + 1;

  /// The id of the pack of the lines of its pages.
  String get layoutPackId => 'layout-$name';

  /// The id of the pack of its 604 page fonts.
  String get fontsPackId => 'fonts-$name';

  /// The font family of one page's glyphs. Each page has a font of its own.
  String fontFamily(int page) => 'qcf${number}_p$page';

  /// Where the font of [page] is kept, relative to the Quran folder.
  String fontPath(int page) => 'fonts/$name/p$page.ttf';
}
