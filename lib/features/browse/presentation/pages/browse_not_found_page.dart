import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/empty_state.dart';

/// Shown when a browse location names something that does not exist (an s, ch
/// or page out of range, or a ch that the table does not list for that s).
class BrowseNotFoundPage extends StatelessWidget {
  const BrowseNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(),
      body: EmptyState(
        icon: Icons.search_off_rounded,
        title: l10n.routeNotFoundTitle,
        message: l10n.routeNotFoundMessage,
        actions: [
          FilledButton(
            onPressed: () => context.go(AppRoutes.browse),
            child: Text(l10n.browseTitle),
          ),
        ],
      ),
    );
  }
}
