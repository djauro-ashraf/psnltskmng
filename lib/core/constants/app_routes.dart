/// Every route path lives here so no string literal is repeated in the app.
abstract final class AppRoutes {
  static const String today = '/today';
  static const String settings = '/settings';
  static const String overview = '/overview';

  /// The Browse tab (ps, ss, ch). Its detail routes are children of it; see
  /// `features/browse/presentation/browse_paths.dart`.
  static const String browse = '/browse';

  /// Where the Quran (pages, words, translations) is downloaded. A full
  /// screen above the tabs, reached from Settings and from the Quran side of a
  /// page.
  static const String quranData = '/quran-data';
}
