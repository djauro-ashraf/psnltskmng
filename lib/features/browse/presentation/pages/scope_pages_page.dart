import 'package:flutter/material.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/browse_texts.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_list.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_rows.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The last level of "more details": every page of a scope. Each row opens that
/// page's screen.
class ScopePagesPage extends StatelessWidget {
  const ScopePagesPage({
    super.key,
    required this.scope,
    required this.location,
  });

  final BrowseScope scope;

  /// This list's own location; each row is a child of it.
  final String location;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final first = scope.firstPage;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.browseTrail(scopeTitle(l10n, scope), l10n.browsePsTitle),
        ),
      ),
      body: BrowseList(
        sections: [
          BrowseSection(
            itemCount: scope.pageCount,
            itemBuilder: (context, index) {
              final page = first + index;
              return PageRow(page: page, path: '$location/$page');
            },
          ),
        ],
      ),
    );
  }
}
