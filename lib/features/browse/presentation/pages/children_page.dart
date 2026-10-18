import 'package:flutter/material.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/presentation/browse_texts.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_list.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/browse_rows.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The first level of "more details": the ch of an s that spans several ch, or
/// the s of a ch that touches several s. Each row opens that part, whose own
/// "More details" lists its pages.
class ChildrenPage extends StatelessWidget {
  const ChildrenPage({super.key, required this.scope, required this.location});

  /// An [SScope] (lists its ch) or a [ChScope] (lists its s).
  final BrowseScope scope;

  /// This list's own location; each row is a child of it.
  final String location;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = BrowseIndex.instance.children(scope);
    final byCh = scope is SScope;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.browseTrail(
            scopeTitle(l10n, scope),
            byCh ? l10n.browseChTitle : l10n.browseSsTitle,
          ),
        ),
      ),
      body: BrowseList(
        sections: [
          BrowseSection(
            itemCount: parts.length,
            itemBuilder: (context, index) {
              final part = parts[index];
              return PartRow(
                part: part,
                byCh: byCh,
                path: '$location/${byCh ? part.ch : part.s}',
              );
            },
          ),
        ],
      ),
    );
  }
}
