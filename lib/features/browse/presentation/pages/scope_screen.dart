import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/pages/page_detail_page.dart';
import 'package:personaltskmng/features/browse/presentation/pages/scope_detail_page.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';

/// What opens when a unit that is not a page is opened (an s, a ch, a part).
///
/// - In the Info mode: the unit's info, with "More details" down to its pages
///   ([ScopeDetailPage]).
/// - In the Quran mode: straight to the pages of the unit, one pager over its
///   own range and no others ([PageDetailPage]). The levels in between have
///   nothing to say there, so there is no "More details" to go through. The
///   pages are ordinary page screens: Info on one shows that page's info and
///   notes, and the Quran switch brings the reading back.
///
/// The mode is read when the screen opens, and the screen follows the switch
/// of the unit's info (Quran there goes to the pages). It never goes the other
/// way: once reading the pages, the unit stays the pager.
class ScopeScreen extends ConsumerStatefulWidget {
  const ScopeScreen({super.key, required this.scope, required this.location});

  final BrowseScope scope;

  /// This screen's own location; the next screen is a child of it.
  final String location;

  @override
  ConsumerState<ScopeScreen> createState() => _ScopeScreenState();
}

class _ScopeScreenState extends ConsumerState<ScopeScreen> {
  late bool _reading;

  @override
  void initState() {
    super.initState();
    _reading = ref.read(pageSideProvider) == PageSide.quran;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PageSide>(pageSideProvider, (previous, next) {
      if (next == PageSide.quran && !_reading) {
        setState(() => _reading = true);
      }
    });

    final scope = widget.scope;
    if (!_reading) {
      return ScopeDetailPage(scope: scope, location: widget.location);
    }
    final first = scope.firstPage;
    final last = scope.lastPage;
    return PageDetailPage(
      // A new pager when the range changes (a sibling opened in its place).
      key: ValueKey('$first-$last'),
      page: first,
      first: first,
      last: last,
    );
  }
}
