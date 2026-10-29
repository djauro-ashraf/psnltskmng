import 'package:personaltskmng/core/constants/app_routes.dart';

/// Locations of the browse routes. The tab root hosts the ps / ss / ch lists;
/// everything below it is a detail screen:
///
/// ```
/// /browse/ps/:page                       p (blank for now)
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
/// ```
abstract final class BrowsePaths {
  static const String root = AppRoutes.browse;
  static const String ps = '$root/ps';
  static const String ss = '$root/ss';
  static const String ch = '$root/ch';

  static final RegExp _pageScreen = RegExp(
    '^${RegExp.escape(root)}/(?:.*/)?ps/\\d+/?\$',
  );

  /// True for the location of a page screen (`.../ps/:page`), false for
  /// everything else, the list of pages (`.../ps`) included.
  static bool isPageScreen(String location) => _pageScreen.hasMatch(location);

  static final RegExp _scopeScreen = RegExp(
    '^${RegExp.escape(root)}/'
    '(?:ss/\\d+(?:/ch/\\d+)?|ch/\\d+(?:/ss/\\d+)?)/?\$',
  );

  /// True for the location of the screen of an s, a ch or a part
  /// (`/ss/:s`, `/ss/:s/ch/:ch`, `/ch/:ch`, `/ch/:ch/ss/:s`), false for their
  /// lists (`.../ch`, `.../ss`, `.../ps`).
  static bool isScopeScreen(String location) => _scopeScreen.hasMatch(location);

  /// A screen that has the Quran as its other side: a page, or a unit (whose
  /// Quran side is its pages).
  static bool isReadingScreen(String location) =>
      isPageScreen(location) || isScopeScreen(location);
}
