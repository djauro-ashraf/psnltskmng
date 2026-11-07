import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/controller/ayah_copy_loader.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';
import 'package:personaltskmng/quran_data/models/ayah_copy.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

Future<void> showAyahCopySheet(
  BuildContext context, {
  required AyahRef ayah,
  AyahRange? range,
  void Function(AyahRef ayah, String? prompt)? onAskAi,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => AyahCopySheet(
      initialAyah: ayah,
      initialRange: range ?? AyahRange(ayah, ayah),
      onAskAi: onAskAi,
    ),
  );
}

class AyahCopySheet extends ConsumerStatefulWidget {
  const AyahCopySheet({
    super.key,
    required this.initialAyah,
    required this.initialRange,
    this.onAskAi,
  });

  final AyahRef initialAyah;
  final AyahRange initialRange;
  final void Function(AyahRef ayah, String? prompt)? onAskAi;

  @override
  ConsumerState<AyahCopySheet> createState() => _AyahCopySheetState();
}

class _AyahCopySheetState extends ConsumerState<AyahCopySheet> {
  late AyahRange _range = widget.initialRange;
  late CopyRecipe _recipe;
  String? _tafsirSourceId;
  List<TafsirSource> _sources = const [];
  bool _isCopying = false;

  @override
  void initState() {
    super.initState();
    _recipe = ref.read(copyRecipeProvider);
    _tafsirSourceId = ref.read(tafsirSourceProvider);
    _loadSources();
  }

  Future<void> _loadSources() async {
    final sources = await ref.read(tafsirContentProvider).installed();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      if (sources.isNotEmpty &&
          (_tafsirSourceId == null ||
              !sources.any((s) => s.id == _tafsirSourceId))) {
        _tafsirSourceId = sources.first.id;
      }
    });
  }

  String _formatRangeLabel(AyahRange r) {
    if (r.first == r.last) return r.first.key;
    if (r.first.surah == r.last.surah) {
      return '${r.first.key}–${r.last.ayah}';
    }
    return '${r.first.key}–${r.last.key}';
  }

  void _updateRecipe(CopyRecipe newRecipe) {
    setState(() => _recipe = newRecipe);
    ref.read(copyRecipeProvider.notifier).set(newRecipe);
  }

  void _togglePart(CopyPart part) {
    final newParts = Set<CopyPart>.from(_recipe.parts);
    if (newParts.contains(part)) {
      newParts.remove(part);
    } else {
      newParts.add(part);
    }
    _updateRecipe(_recipe.copyWith(parts: newParts));
  }

  void _toggleReference() {
    _updateRecipe(_recipe.copyWith(reference: !_recipe.reference));
  }

  Future<void> _extendPlusOne() async {
    final nextIndex = _range.last.index + 1;
    if (nextIndex < QuranDivisions.ayahCount) {
      setState(() {
        _range = AyahRange(_range.first, QuranDivisions.fromIndex(nextIndex));
      });
    }
  }

  Future<void> _extendToEndOfPage() async {
    final locator = ref.read(pageLocatorProvider);
    final page = await locator.pageOf(_range.last);
    if (page != null) {
      final lastAyah = await locator.lastAyahOf(page);
      if (lastAyah != null && lastAyah >= _range.first) {
        setState(() {
          _range = AyahRange(_range.first, lastAyah);
        });
      }
    }
  }

  void _extendToEndOfRuku() {
    final ruku = QuranDivisions.rukuOf(_range.last);
    if (ruku.last >= _range.first) {
      setState(() {
        _range = AyahRange(_range.first, ruku.last);
      });
    }
  }

  void _resetRange() {
    setState(() => _range = widget.initialRange);
  }

  Future<void> _performCopy({String? aiInstruction}) async {
    if (_isCopying) return;
    setState(() => _isCopying = true);
    final l10n = context.l10n;

    try {
      final inputs = await AyahCopyLoader.load(
        ref: ref,
        range: _range,
        recipe: _recipe,
        tafsirSourceId: _tafsirSourceId,
      );

      final result = AyahCopy.build(
        inputs,
        _recipe,
        aiInstruction: aiInstruction,
      );

      await Clipboard.setData(ClipboardData(text: result.text));

      if (mounted) {
        showAppSnackBar(
          context,
          result.isTruncated
              ? l10n.copyTruncatedNotice
              : l10n.readerCopied,
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, l10n.mushafBroken, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isCopying = false);
    }
  }

  Future<void> _editCustomPromptAndCopy() async {
    final l10n = context.l10n;
    final current = ref.read(aiCopyInstructionProvider);
    final controller = TextEditingController(text: current);

    final updated = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.copyCustomPromptDialogTitle),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(MaterialLocalizations.of(dialogCtx).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(controller.text),
            child: Text(MaterialLocalizations.of(dialogCtx).okButtonLabel),
          ),
        ],
      ),
    );

    if (updated != null && updated.trim().isNotEmpty) {
      await ref.read(aiCopyInstructionProvider.notifier).set(updated);
      await _performCopy(aiInstruction: updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final rangeLabel = _formatRangeLabel(_range);
    final hasTafsirPacks = _sources.isNotEmpty;
    final isExtended = _range != widget.initialRange;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.copySheetTitle(rangeLabel),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_isCopying)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Checkboxes
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                FilterChip(
                  label: Text(l10n.copyArabic),
                  selected: _recipe.parts.contains(CopyPart.arabic),
                  onSelected: (_) => _togglePart(CopyPart.arabic),
                ),
                FilterChip(
                  label: Text(l10n.copyTranslation),
                  selected: _recipe.parts.contains(CopyPart.translation),
                  onSelected: (_) => _togglePart(CopyPart.translation),
                ),
                FilterChip(
                  label: Text(l10n.copyWords),
                  selected: _recipe.parts.contains(CopyPart.words),
                  onSelected: (_) => _togglePart(CopyPart.words),
                ),
                FilterChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.copyTafsir),
                      if (hasTafsirPacks && _sources.length > 1) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down, size: 18),
                      ],
                    ],
                  ),
                  selected: hasTafsirPacks &&
                      _recipe.parts.contains(CopyPart.tafsir),
                  onSelected: hasTafsirPacks
                      ? (_) => _togglePart(CopyPart.tafsir)
                      : null,
                ),
                FilterChip(
                  label: Text(l10n.copyReference(rangeLabel)),
                  selected: _recipe.reference,
                  onSelected: (_) => _toggleReference(),
                ),
              ],
            ),

            // Tafsir source picker if multiple installed and tafsir selected
            if (hasTafsirPacks &&
                _sources.length > 1 &&
                _recipe.parts.contains(CopyPart.tafsir)) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    '${l10n.copyTafsir}: ',
                    style: theme.textTheme.bodySmall,
                  ),
                  DropdownButton<String>(
                    value: _tafsirSourceId,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      for (final s in _sources)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(
                            s.title,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                    onChanged: (id) {
                      if (id != null) {
                        setState(() => _tafsirSourceId = id);
                        ref.read(tafsirSourceProvider.notifier).set(id);
                      }
                    },
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppSpacing.md),
            const Divider(),

            // Presets
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Text(
                    l10n.copyPresets,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            label: Text(l10n.copyPresetArabicOnly),
                            onPressed: () =>
                                _updateRecipe(CopyRecipe.arabicOnly),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ActionChip(
                            label: Text(l10n.copyPresetArabicTranslation),
                            onPressed: () => _updateRecipe(
                              CopyRecipe.arabicAndTranslation,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ActionChip(
                            label: Text(l10n.copyPresetEverything),
                            onPressed: () =>
                                _updateRecipe(CopyRecipe.everything),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Extend range
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Text(
                    l10n.copyExtendTo,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ActionChip(
                            label: Text(l10n.copyExtendPlusOne),
                            onPressed: _extendPlusOne,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ActionChip(
                            label: Text(l10n.copyExtendPage),
                            onPressed: _extendToEndOfPage,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ActionChip(
                            label: Text(l10n.copyExtendRuku),
                            onPressed: _extendToEndOfRuku,
                          ),
                          if (isExtended) ...[
                            const SizedBox(width: AppSpacing.xs),
                            ActionChip(
                              avatar: const Icon(Icons.refresh, size: 16),
                              label: Text(l10n.copyResetRange),
                              onPressed: _resetRange,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text(l10n.readerCopy),
                    onPressed: _isCopying ? null : () => _performCopy(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    switch (action) {
                      case 'explain':
                        _performCopy(
                          aiInstruction: AiCopyInstructions.explain,
                        );
                        break;
                      case 'simplify_tafsir':
                        _performCopy(
                          aiInstruction: AiCopyInstructions.simplifyTafsir,
                        );
                        break;
                      case 'custom':
                        _editCustomPromptAndCopy();
                        break;
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'explain',
                      child: Text(l10n.copyExplainSimply),
                    ),
                    if (_recipe.parts.contains(CopyPart.tafsir))
                      PopupMenuItem(
                        value: 'simplify_tafsir',
                        child: Text(l10n.copySimplifyTafsir),
                      ),
                    PopupMenuItem(
                      value: 'custom',
                      child: Text(l10n.copyCustomPrompt),
                    ),
                  ],
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: Text(l10n.copyForAi),
                    onPressed: null, // Tap handled by PopupMenuButton child
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
