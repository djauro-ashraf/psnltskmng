import 'package:flutter/material.dart';
import 'package:personaltskmng/ai/ai_models.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// The very short, translated line shown under a model of the list.
String aiModelNoteText(AppLocalizations l10n, AiModelNote note) =>
    switch (note) {
      AiModelNote.newest => l10n.aiModelNoteNewest,
      AiModelNote.balanced => l10n.aiModelNoteBalanced,
      AiModelNote.light => l10n.aiModelNoteLight,
      AiModelNote.largest => l10n.aiModelNoteLargest,
      AiModelNote.small => l10n.aiModelNoteSmall,
    };

/// Opens the list of free models of [provider]. Returns the id of the model the
/// user tapped, or null when the sheet was closed without a choice. [current]
/// is the text now in the model field (the matching row is highlighted).
Future<String?> showModelPickerSheet(
  BuildContext context, {
  required AiProviderInfo provider,
  required String current,
}) => showModalBottomSheet<String>(
  context: context,
  useSafeArea: true,
  builder: (context) => ModelPickerSheet(provider: provider, current: current),
);

/// The models a free account can use, each with a few words about it; the clear
/// first choice carries a "Recommended" badge. Typing any other model name in
/// the field stays possible: this list is only a shortcut.
class ModelPickerSheet extends StatelessWidget {
  const ModelPickerSheet({
    super.key,
    required this.provider,
    required this.current,
  });

  final AiProviderInfo provider;
  final String current;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xs,
          ),
          child: Text(
            l10n.aiModelPickerTitle,
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(l10n.aiModelPickerHint, style: theme.textTheme.bodySmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final model in provider.models)
                ListTile(
                  selected: model.id == current.trim(),
                  title: Text(model.id),
                  subtitle: Text(aiModelNoteText(l10n, model.note)),
                  trailing: model.recommended
                      ? _RecommendedBadge(label: l10n.aiModelRecommended)
                      : null,
                  onTap: () => Navigator.of(context).pop(model.id),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
