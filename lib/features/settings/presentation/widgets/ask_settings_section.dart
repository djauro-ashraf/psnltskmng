import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/ai/gemini_chat.dart';
import 'package:personaltskmng/ai/groq_chat.dart';
import 'package:personaltskmng/ask/controller/ask_providers.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/ai_setup_view_model.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/model_picker_sheet.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// The Quran assistant (Ask AI): the switch, the provider, the model, the API
/// key, the language and length of the answers, and the saved chats.
///
/// Its own settings, not the planner's: the planner can be off while the
/// assistant is on, with another provider or model. Only the keys are shared
/// (one key store, one key per provider). Saved at once, not with the Save
/// button; the Ask buttons of the reader show once the switch is on and a key is
/// saved for the provider chosen here.
class AskSettingsSection extends ConsumerStatefulWidget {
  const AskSettingsSection({super.key});

  /// The model the chat falls back to for [providerId] when the field is empty.
  static String chatDefaultModel(String providerId) => switch (providerId) {
    'groq' => GroqChat.defaultModel,
    'gemini' => GeminiChat.defaultModel,
    _ => aiProviderInfo(providerId).defaultModel,
  };

  /// "1.4 KB", "3.2 MB": the room the chats take.
  static String sizeLabel(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  ConsumerState<AskSettingsSection> createState() => _AskSettingsSectionState();
}

class _AskSettingsSectionState extends ConsumerState<AskSettingsSection> {
  final TextEditingController _key = TextEditingController();

  /// One model field controller per provider (each keeps its own text).
  final Map<String, TextEditingController> _models = {};

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
    ref.read(askSettingsProvider.notifier).setModel(provider.id, picked);
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

  Future<void> _deleteAll() async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.askDeleteAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.aiSavedKeyDelete),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    await ref.read(chatListProvider.notifier).deleteAll();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(askSettingsProvider);
    final notifier = ref.read(askSettingsProvider.notifier);
    final setup = ref.watch(aiSetupViewModelProvider);
    final provider = aiProviderInfo(settings.provider);
    final hasKey = setup.providersWithKey.contains(provider.id);
    final storage = ref.watch(chatStorageProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.askEnable),
          value: settings.enabled,
          onChanged: notifier.setEnabled,
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
                onSelected: (_) => notifier.setProvider(info.id),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          // A new field per provider, so the shown model is that provider's.
          key: ValueKey('ask-model-${provider.id}'),
          controller: _modelController(
            provider.id,
            settings.models[provider.id] ?? '',
          ),
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: l10n.aiModelLabel,
            helperText: l10n.aiModelDefault(
              AskSettingsSection.chatDefaultModel(provider.id),
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
        if (settings.enabled && !hasKey) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.askNeedsKey,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Text(l10n.askLanguageLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final (code, label) in [
              ('auto', l10n.askLanguageAuto),
              // The languages are named in their own language, as written.
              ('en', 'English'),
              ('fr', 'Français'),
              ('ar', 'العربية'),
            ])
              ChoiceChip(
                label: Text(label),
                selected: settings.answerLanguage == code,
                onSelected: (_) => notifier.setLanguage(code),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.askLengthLabel, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: Text(l10n.askLengthNormal),
              selected: settings.answerLength != 'short',
              onSelected: (_) => notifier.setLength('normal'),
            ),
            ChoiceChip(
              label: Text(l10n.askLengthShort),
              selected: settings.answerLength == 'short',
              onSelected: (_) => notifier.setLength('short'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (storage != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.askStorageSummary(
                    storage.count,
                    AskSettingsSection.sizeLabel(storage.bytes),
                  ),
                ),
              ),
              TextButton(
                onPressed: storage.count == 0 ? null : _deleteAll,
                child: Text(l10n.askDeleteAllChats),
              ),
            ],
          ),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.askPrivacy, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
