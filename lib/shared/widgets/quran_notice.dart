import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// A message in the middle of the Quran side (the pages or the words are not
/// downloaded, a file is damaged), with a button to the Quran data screen where
/// they are downloaded.
class QuranNotice extends StatelessWidget {
  const QuranNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: () => context.push(AppRoutes.quranData),
              child: Text(context.l10n.quranDataOpen),
            ),
          ],
        ),
      ),
    );
  }
}
