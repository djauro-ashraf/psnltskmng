import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';

/// Which pages are SHARED: a page that sits in more than one unit, so that
/// working through the units one after the other goes over the same page twice.
///
/// - Two neighbouring ch share a boundary page (page 106 is in ch 12 and ch 13;
///   26 pages, `ChTable.sharedPages`).
/// - Two or three s share a page where one s ends and the next begins (page 106
///   is in s 4 and s 5; page 604 is in s 112, 113 and 114; 51 pages,
///   `STable.sharedPages`).
///
/// The rule this serves (see `RulesEngine.applyR`): a page earns at most ONE
/// unit per day, but a user who goes through two ch, or two s, that meet on a
/// page logs that page twice. The second log is accepted and adds nothing to
/// the page; it is not an error. Only a page that sits in one ch AND one s is
/// not shared, and there a second successful R the same day is still refused.
///
/// Only the 604-page Q the tables describe has shared pages; for any other
/// size nothing is shared (as for merging).
///
/// Pure Dart.
abstract final class SharedPages {
  /// Whether [q] is the Q the tables describe ([ChTable.totalPages] pages).
  static bool covers(Q q) => q.totalPages == ChTable.totalPages;

  /// Whether [page] (1 to [ChTable.totalPages]) is in two or more ch or in two
  /// or more s. A page outside the table is not shared.
  static bool isShared(int page) {
    if (page < 1 || page > ChTable.totalPages) return false;
    return ChTable.instance.chOfPage(page).length > 1 ||
        STable.sOfPage(page).length > 1;
  }

  /// [isShared] on a page of [q]: always false for a Q the tables do not
  /// describe.
  static bool isSharedIn(Q q, int page) => covers(q) && isShared(page);

  /// Every shared page (ch or s), ascending.
  static List<int> get all => _all;
  static final List<int> _all = List<int>.unmodifiable([
    for (var page = 1; page <= ChTable.totalPages; page++)
      if (isShared(page)) page,
  ]);
}
