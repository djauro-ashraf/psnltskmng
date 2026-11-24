import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/agent/controller/agent_providers.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/agent/presentation/agent_text.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/model_picker_sheet.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// The agent: the switch, its own provider, model and API key, and whether it
/// asks before it acts.
///
/// Its own settings AND its own key: it can use another provider, another
/// model and another key than the planner and the assistant (the key is kept
/// under its own name in the secure store, so saving or removing it never
/// touches theirs). Saved at once, not with a Save button. The command button
/// of the app shows once the switch is on and a key is saved.
class AgentSettingsSection extends ConsumerStatefulWidget {
  const AgentSettingsSection({super.key});

  @override
  ConsumerState<AgentSettingsSection> createState() =>
      _AgentSettingsSectionState();
}

class _AgentSettingsSectionState extends ConsumerState<AgentSettingsSection> {
  final TextEditingController _key = TextEditingController();

  /// One model field controller per provider (each keeps its own text).
  final Map<String, TextEditingController> _models = {};

  bool _busy = false;

  @override
  void dispose() {
    _key.dispose();
    for (final controller in _models.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _modelController(String providerId, String initial) =>
      _models.putIfAbsent(
        providerId,
        () => TextEditingController(text: initial),
      );

  Future<void> _pickModel(AiProviderInfo provider) async {
    final controller = _modelController(provider.id, '');
    final picked = await showModelPickerSheet(
      context,
      provider: provider,
      current: controller.text,
    );
    if (picked == null || !mounted) return;
    controller.text = picked;
    ref.read(agentSettingsProvider.notifier).setModel(provider.id, picked);
  }

  Future<void> _saveKey(String providerId) async {
    final l10n = context.l10n;
    final value = _key.text.trim();
    if (value.isEmpty || _busy) return;
    setState(() => _busy = true);
    var ok = true;
    try {
      await ref.read(agentKeysProvider).write(providerId, value);
      ref.invalidate(agentHasKeyProvider);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) _key.clear();
    showAppSnackBar(
      context,
      ok ? l10n.aiKeySavedMessage : l10n.aiKeyFailed,
      isError: !ok,
    );
  }

  Future<void> _removeKey(String providerId) async {
    final l10n = context.l10n;
    if (_busy) return;
    setState(() => _busy = true);
    var ok = true;
    try {
      await ref.read(agentKeysProvider).delete(providerId);
      ref.invalidate(agentHasKeyProvider);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showAppSnackBar(
      context,
      ok ? l10n.aiKeyRemovedMessage : l10n.aiKeyFailed,
      isError: !ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AgentText.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(agentSettingsProvider);
    final notifier = ref.read(agentSettingsProvider.notifier);
    final provider = aiProviderInfo(settings.provider);
    final hasKey = ref.watch(agentHasKeyProvider).value ?? false;
    final available = ref.watch(agentAvailableProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(text.enable),
          subtitle: Text(text.enableHelp),
          value: settings.enabled,
          onChanged: notifier.setEnabled,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.aiProviderLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final info in aiProviderInfos)
              ChoiceChip(
                label: Text(info.name),
                selected: info.id == provider.id,
                onSelected: (_) => notifier.setProvider(info.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          // A new field per provider, so the shown model is that provider's.
          key: ValueKey('agent-model-${provider.id}'),
          controller: _modelController(
            provider.id,
            settings.models[provider.id] ?? '',
          ),
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.aiModelLabel,
            helperText: l10n.aiModelDefault(
              AgentSettings.defaultModelOf(provider.id),
            ),
            helperMaxLines: 2,
            suffixIcon: provider.models.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.arrow_drop_down),
                    tooltip: l10n.aiModelPickerTitle,
                    onPressed: () => _pickModel(provider),
                  ),
          ),
          onChanged: (value) => notifier.setModel(provider.id, value),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _key,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          decoration: InputDecoration(
            labelText: l10n.aiKeyLabel,
            helperText: text.keyHelp,
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(hasKey ? l10n.aiKeySaved : l10n.aiKeyNone),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            FilledButton.tonal(
              onPressed: _busy ? null : () => _saveKey(provider.id),
              child: Text(l10n.aiKeySave),
            ),
            TextButton(
              onPressed: _busy || !hasKey ? null : () => _removeKey(provider.id),
              child: Text(l10n.aiKeyRemove),
            ),
          ],
        ),
        if (settings.enabled && !hasKey) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            text.needsKey,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(text.approvalAsk),
          subtitle: Text(text.approvalHelp),
          value: settings.approval == AgentApproval.ask,
          onChanged: (ask) => notifier.setApproval(
            ask ? AgentApproval.ask : AgentApproval.auto,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(text.shareNotes),
          subtitle: Text(text.shareNotesHelp),
          value: settings.shareNotes,
          onChanged: notifier.setShareNotes,
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: available ? () => context.push(AppRoutes.agent) : null,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text(text.tryIt),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(text.privacy, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
