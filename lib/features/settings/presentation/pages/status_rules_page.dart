import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/number_setting_tile.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';
import 'package:personaltskmng/memo/rules/rules_preview.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// The numbers behind the statuses, made understandable: pick a starting point
/// (Original, Relaxed, Strict), see in plain words what the numbers do to a new
/// ayah (run on the real engine, so it is always true), then adjust any number,
/// each explained. Editing a step of a ladder (a warning, a stronger warning,
/// the fall) moves the others just enough to keep them in order, and says so.
/// Nothing is saved until Save.
class StatusRulesPage extends ConsumerStatefulWidget {
  const StatusRulesPage({super.key});

  @override
  ConsumerState<StatusRulesPage> createState() => _StatusRulesPageState();
}

class _StatusRulesPageState extends ConsumerState<StatusRulesPage> {
  late StatusRules _rules;
  Set<String> _moved = const {};
  int _every = 1;

  @override
  void initState() {
    super.initState();
    _rules = ref.read(memoProvider).settings.rules;
  }

  void _set(String key, int value) {
    final moved = <String>{};
    final next = _rules.adjusted(key, value, moved: moved);
    setState(() {
      _rules = next;
      _moved = moved;
    });
  }

  Future<void> _save() async {
    final text = MemoText.of(context);
    final memo = ref.read(memoProvider);
    try {
      await ref
          .read(memoProvider.notifier)
          .setSettings(memo.settings.copyWith(rules: _rules));
      if (mounted) {
        showAppSnackBar(context, text.saved);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, text.storageError, isError: true);
    }
  }

  /// The smallest and the largest value a rule key may take.
  ({int min, int max}) _range(String key) {
    if (key.startsWith('target') || key.startsWith('primeTarget')) {
      return (min: 1, max: 99);
    }
    if (key.startsWith('forgive') || key.startsWith('penalty')) {
      return (min: 0, max: 99);
    }
    if (key.startsWith('gap') || key.startsWith('primeGap')) {
      return (min: 1, max: 60);
    }
    return (min: 1, max: 365);
  }

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final saved = ref.read(memoProvider).settings.rules;
    final changed = _rules != saved;
    final preset = _rules.preset;
    final preview = RulesPreview.compute(_rules, everyDays: _every);

    final children = <Widget>[
      Text(text.rulesHelp, style: theme.textTheme.bodyMedium),
      const SizedBox(height: AppSpacing.md),
      Text(text.presetsTitle, style: theme.textTheme.titleSmall),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        children: [
          for (final p in RulesPreset.values)
            ChoiceChip(
              label: Text(text.preset(p)),
              selected: preset == p,
              onSelected: (_) => setState(() {
                _rules = StatusRules.ofPreset(p);
                _moved = const {};
              }),
            ),
          if (preset == null)
            ChoiceChip(
              label: Text(text.preset(null)),
              selected: true,
              onSelected: null,
            ),
        ],
      ),
      if (preset != null) ...[
        const SizedBox(height: AppSpacing.xs),
        Text(
          text.presetHelp(preset),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.lg),
      Card(
        color: theme.colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text.previewTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                children: [
                  Text(text.previewEveryLabel),
                  DropdownButton<int>(
                    value: _every,
                    items: [
                      for (final n in const [1, 2, 3, 5, 7])
                        DropdownMenuItem(
                          value: n,
                          child: Text(text.previewEveryValue(n)),
                        ),
                    ],
                    onChanged: (n) {
                      if (n != null) setState(() => _every = n);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                preview.reachesConsolidated
                    ? text.previewReaches(
                        preview.learning2Day!,
                        preview.learning3Day!,
                        preview.consolidatedDay!,
                        preview.reviewsToConsolidate!,
                      )
                    : text.previewNever,
                style: preview.reachesConsolidated
                    ? theme.textTheme.bodyMedium
                    : theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                text.previewNeverReviewed(
                  _rules.fade1(1, prime: false),
                  _rules.fade2(1, prime: false),
                  _rules.drop(1, prime: false),
                ),
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                text.previewLeftAlone(
                  _rules.consolidatedFade1,
                  _rules.consolidatedFade2,
                  _rules.consolidatedForgotten,
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
      if (_moved.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.md),
        Text(
          text.movedAlso([for (final k in _moved) text.ruleLabel(k)]),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.tertiary,
          ),
        ),
      ],
    ];

    String? group;
    for (final key in StatusRules.keys) {
      final g = text.ruleGroup(key);
      if (g != group) {
        group = g;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl, bottom: AppSpacing.xs),
            child: Text(g, style: theme.textTheme.titleMedium),
          ),
        );
        if (key.startsWith('target')) {
          children.add(
            Text(
              text.rulesGroupIntroClimb,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }
      }
      final info = text.ruleInfo(key);
      final range = _range(key);
      children.add(
        NumberSettingTile(
          title: text.ruleLabel(key),
          what: info.what,
          raise: info.raise,
          lower: info.lower,
          unit: info.unit,
          value: _rules.value(key),
          defaultValue: StatusRules.defaults.value(key),
          min: range.min,
          max: range.max,
          onChanged: (v) => _set(key, v),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(text.rulesTitle),
        actions: [
          IconButton(
            tooltip: text.rulesReset,
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () => setState(() {
              _rules = StatusRules.defaults;
              _moved = const {};
            }),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton(
              onPressed: changed ? _save : null,
              child: Text(text.saveButton),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: children,
          ),
        ),
      ),
    );
  }
}
