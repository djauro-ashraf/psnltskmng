import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/ai_setup_view_model.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// The AI planner setup: the switch, the provider, the model and the API key.
/// The switch, provider and model are the app's own settings; the key goes to
/// the secure key store and is never shown again after saving. Every change
/// applies from the next plan. These are not planning settings: they are saved
/// at once, not with the Save button.
class AiPlannerSection extends ConsumerStatefulWidget {
  const AiPlannerSection({super.key});

  @override
  ConsumerState<AiPlannerSection> createState() => _AiPlannerSectionState();
}

class _AiPlannerSectionState extends ConsumerState<AiPlannerSection> {
  final TextEditingController _key = TextEditingController();

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _saveKey(String providerId) async {
    final l10n = context.l10n;
    final ok = await ref
        .read(aiSetupViewModelProvider.notifier)
        .saveKey(providerId, _key.text);
    if (!mounted) return;
    if (ok) _key.clear();
    showAppSnackBar(
      context,
      ok ? l10n.aiKeySavedMessage : l10n.aiKeyFailed,
      isError: !ok,
    );
  }

  Future<void> _removeKey(String providerId) async {
    final l10n = context.l10n;
    final ok = await ref
        .read(aiSetupViewModelProvider.notifier)
        .removeKey(providerId);
    if (!mounted) return;
    showAppSnackBar(
      context,
      ok ? l10n.aiKeyRemovedMessage : l10n.aiKeyFailed,
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsViewModelProvider);
    final setup = ref.watch(aiSetupViewModelProvider);
    final vm = ref.read(aiSetupViewModelProvider.notifier);
    final provider = aiProviderInfo(settings.aiProvider);
    final hasKey = setup.providersWithKey.contains(provider.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.aiEnable),
          value: settings.aiEnabled,
          onChanged: (value) => vm.setEnabled(value),
        ),
        Text(l10n.aiProviderLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final info in aiProviderInfos)
              ChoiceChip(
                label: Text(info.name),
                selected: info.id == provider.id,
                onSelected: (_) => vm.setProvider(info.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          // A new field per provider, so the shown model is that provider's.
          key: ValueKey('model-${provider.id}'),
          initialValue: settings.aiModels[provider.id] ?? '',
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.aiModelLabel,
            helperText: l10n.aiModelDefault(provider.defaultModel),
            helperMaxLines: 2,
          ),
          onChanged: (value) => vm.setModel(provider.id, value),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          decoration: InputDecoration(labelText: l10n.aiKeyLabel),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(hasKey ? l10n.aiKeySaved : l10n.aiKeyNone),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilledButton.tonal(
              onPressed: setup.busy ? null : () => _saveKey(provider.id),
              child: Text(l10n.aiKeySave),
            ),
            TextButton(
              onPressed: setup.busy || !hasKey
                  ? null
                  : () => _removeKey(provider.id),
              child: Text(l10n.aiKeyRemove),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (settings.aiEnabled && !hasKey) Text(l10n.aiNeedsKey),
        Text(l10n.aiOfflineNote, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.aiPrivacy, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
