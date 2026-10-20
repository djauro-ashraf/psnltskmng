import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/saved_keys_view_model.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

/// Opens the keys saved on this device for [provider]. Returns the id of the key
/// the user tapped (to use it), or null when the sheet was closed without a
/// choice. [draftKey] is what the key field holds now; it is offered as the key
/// of a new saved key, so a key just pasted does not have to be typed again.
Future<String?> showSavedKeysSheet(
  BuildContext context, {
  required AiProviderInfo provider,
  String draftKey = '',
}) => showModalBottomSheet<String>(
  context: context,
  useSafeArea: true,
  builder: (context) => SavedKeysSheet(provider: provider, draftKey: draftKey),
);

/// The named keys of one provider: tap one to use it, add a new one, delete one.
/// They are kept on this device only and never reach the backup (the sheet says
/// so). The list shows names, never keys.
class SavedKeysSheet extends ConsumerStatefulWidget {
  const SavedKeysSheet({
    super.key,
    required this.provider,
    this.draftKey = '',
  });

  final AiProviderInfo provider;
  final String draftKey;

  @override
  ConsumerState<SavedKeysSheet> createState() => _SavedKeysSheetState();
}

class _SavedKeysSheetState extends ConsumerState<SavedKeysSheet> {
  /// The last add or delete failed (the secure store said no).
  bool _failed = false;

  Future<void> _add(List<SavedKeyEntry> entries) async {
    final entered = await showDialog<({String name, String key})>(
      context: context,
      builder: (context) => _AddSavedKeyDialog(
        existingNames: [for (final e in entries) e.name],
        initialKey: widget.draftKey,
      ),
    );
    if (entered == null || !mounted) return;
    final result = await ref
        .read(savedKeysViewModelProvider.notifier)
        .add(
          providerId: widget.provider.id,
          name: entered.name,
          key: entered.key,
        );
    if (!mounted) return;
    setState(() => _failed = result == SavedKeyResult.failed);
  }

  Future<void> _delete(SavedKeyEntry entry) async {
    final l10n = context.l10n;
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.aiSavedKeyDeleteTitle(entry.name)),
        content: Text(l10n.aiSavedKeyDeleteBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.aiSavedKeyDelete),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final ok = await ref
        .read(savedKeysViewModelProvider.notifier)
        .remove(entry.id);
    if (!mounted) return;
    setState(() => _failed = !ok);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final saved = ref.watch(savedKeysViewModelProvider);
    final entries = saved.forProvider(widget.provider.id);
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
            '${l10n.aiSavedKeysTitle} · ${widget.provider.name}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Text(
            l10n.aiSavedKeysDeviceOnly,
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Text(
              l10n.aiKeyFailed,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Flexible(
          child: !saved.loaded
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                )
              : entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Text(l10n.aiSavedKeysEmpty),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final entry in entries)
                      ListTile(
                        leading: const Icon(Icons.key_outlined),
                        title: Text(entry.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: l10n.aiSavedKeyDelete,
                          onPressed: saved.busy ? null : () => _delete(entry),
                        ),
                        onTap: () => Navigator.of(context).pop(entry.id),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: TextButton.icon(
            onPressed: saved.busy || !saved.loaded
                ? null
                : () => _add(entries),
            icon: const Icon(Icons.add),
            label: Text(l10n.aiSavedKeyAdd),
          ),
        ),
      ],
    );
  }
}

/// Asks for a name and a key. Returns both (trimmed) or null when cancelled.
/// Typing a name that is already saved says that the old key will be replaced.
class _AddSavedKeyDialog extends StatefulWidget {
  const _AddSavedKeyDialog({
    required this.existingNames,
    required this.initialKey,
  });

  final List<String> existingNames;
  final String initialKey;

  @override
  State<_AddSavedKeyDialog> createState() => _AddSavedKeyDialogState();
}

class _AddSavedKeyDialogState extends State<_AddSavedKeyDialog> {
  final TextEditingController _name = TextEditingController();
  late final TextEditingController _key = TextEditingController(
    text: widget.initialKey,
  );

  @override
  void dispose() {
    _name.dispose();
    _key.dispose();
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty && _key.text.trim().isNotEmpty;

  bool get _replaces {
    final typed = _name.text.trim().toLowerCase();
    return typed.isNotEmpty &&
        widget.existingNames.any((n) => n.trim().toLowerCase() == typed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.aiSavedKeyAdd),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(40)],
            decoration: InputDecoration(
              labelText: l10n.aiSavedKeyNameLabel,
              helperText: _replaces ? l10n.aiSavedKeyReplaces : null,
              helperMaxLines: 2,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _key,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(labelText: l10n.aiKeyLabel),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(context).pop((
                  name: _name.text.trim(),
                  key: _key.text.trim(),
                ))
              : null,
          child: Text(l10n.aiKeySave),
        ),
      ],
    );
  }
}
