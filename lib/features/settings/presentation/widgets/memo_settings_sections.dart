import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/pages/status_guide_page.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/memo/presentation/providers/reading_providers.dart';
import 'package:personaltskmng/features/settings/presentation/pages/status_rules_page.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/number_setting_tile.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/planner_prefs.dart';
import 'package:personaltskmng/memo/rules/range_input.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// A titled card of settings.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.xs,
              ),
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A number tile with the card's side padding.
Widget _pad(Widget child) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
  child: child,
);

/// Memorisation settings, in four cards: logging, statuses, reading
/// suggestions, and your pieces and log. Every control saves as soon as it
/// changes, and every number explains itself (see [NumberSettingTile]).
class MemoSettingsSection extends ConsumerWidget {
  const MemoSettingsSection({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    MemoSettings settings,
  ) async {
    try {
      await ref.read(memoProvider.notifier).setSettings(settings);
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, MemoText.of(context).storageError, isError: true);
      }
    }
  }

  Future<void> _eraseReading(BuildContext context, WidgetRef ref) async {
    final text = MemoText.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(text.eraseReadingLabel),
        content: Text(text.eraseReadingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(text.delete),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await ref.read(readingProvider.notifier).erase();
    if (context.mounted) showAppSnackBar(context, text.readingErased);
  }

  Future<void> _startOver(BuildContext context, WidgetRef ref) async {
    final text = MemoText.of(context);
    final scheme = Theme.of(context).colorScheme;
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(text.startOverTitle),
        content: Text(text.startOverBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(text.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(text.startOverAction),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    try {
      final data = ref.read(memoProvider).data;
      await ref.read(memoProvider.notifier).replaceWith(
        data.copyWith(events: const []),
      );
      if (context.mounted) showAppSnackBar(context, text.startOverDone);
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, text.storageError, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    final settings = memo.settings;
    final current = memo.defaultPartition;
    final attention = text.settingInfo('attentionDays');
    final limit = text.settingInfo('attentionLimit');
    final readMin = text.settingInfo('readMin');
    final readMemorise = text.settingInfo('readMemorise');
    final readIdle = text.settingInfo('readIdle');
    final readKeep = text.settingInfo('readKeep');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingsCard(
          title: text.loggingCardTitle,
          children: [
            SwitchListTile(
              title: Text(text.sensibleLabel),
              subtitle: Text(text.sensibleHelp),
              value: settings.sensible,
              onChanged: (v) => _save(context, ref, settings.copyWith(sensible: v)),
            ),
            ListTile(
              title: Text(text.defaultPartitionLabel),
              subtitle: Text(text.defaultPartitionHelp),
              trailing: DropdownButton<String>(
                value: current.id,
                items: [
                  for (final p in memo.partitions)
                    DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (id) {
                  if (id != null) {
                    _save(context, ref, settings.copyWith(partitionId: id));
                  }
                },
              ),
            ),
            _pad(
              NumberSettingTile(
                title: attention.title,
                what: attention.what,
                raise: attention.raise,
                lower: attention.lower,
                unit: text.unitDays(settings.attentionDays),
                value: settings.attentionDays,
                defaultValue: MemoSettings.defaultAttentionDays,
                min: 1,
                max: 60,
                onChanged: (v) => _save(context, ref, settings.copyWith(attentionDays: v)),
              ),
            ),
            _pad(
              NumberSettingTile(
                title: limit.title,
                what: limit.what,
                raise: limit.raise,
                lower: limit.lower,
                unit: text.unitPieces,
                value: settings.attentionLimit,
                defaultValue: MemoSettings.defaultAttentionLimit,
                min: 1,
                max: 100,
                onChanged: (v) => _save(context, ref, settings.copyWith(attentionLimit: v)),
              ),
            ),
          ],
        ),
        _SettingsCard(
          title: text.statusesCardTitle,
          children: [
            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(text.statusGuideOpen),
              subtitle: Text(text.statusGuideOpenHelp),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const StatusGuidePage()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded),
              title: Text(text.rulesTitle),
              subtitle: Text(text.currentRules(settings.rules.preset)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const StatusRulesPage()),
              ),
            ),
          ],
        ),
        _SettingsCard(
          title: text.readingCardTitle,
          children: [
            SwitchListTile(
              title: Text(text.trackReadingLabel),
              subtitle: Text(text.trackReadingHelp),
              value: settings.trackReading,
              onChanged: (v) => _save(context, ref, settings.copyWith(trackReading: v)),
            ),
            if (settings.trackReading) ...[
              _pad(
                NumberSettingTile(
                  title: readMin.title,
                  what: readMin.what,
                  raise: readMin.raise,
                  lower: readMin.lower,
                  unit: 'seconds',
                  format: text.secondsLabel,
                  value: settings.readMinSeconds,
                  defaultValue: MemoSettings.defaultReadMinSeconds,
                  min: 5,
                  max: 3600,
                  step: 15,
                  onChanged: (v) => _save(
                    context,
                    ref,
                    settings.copyWith(
                      readMinSeconds: v,
                      readMemoriseSeconds: settings.readMemoriseSeconds < v
                          ? v
                          : settings.readMemoriseSeconds,
                    ),
                  ),
                ),
              ),
              _pad(
                NumberSettingTile(
                  title: readMemorise.title,
                  what: readMemorise.what,
                  raise: readMemorise.raise,
                  lower: readMemorise.lower,
                  unit: 'seconds',
                  format: text.secondsLabel,
                  value: settings.readMemoriseSeconds,
                  defaultValue: MemoSettings.defaultReadMemoriseSeconds,
                  min: settings.readMinSeconds,
                  max: 36000,
                  step: 30,
                  onChanged: (v) => _save(
                    context,
                    ref,
                    settings.copyWith(readMemoriseSeconds: v),
                  ),
                ),
              ),
              _pad(
                NumberSettingTile(
                  title: readIdle.title,
                  what: readIdle.what,
                  raise: readIdle.raise,
                  lower: readIdle.lower,
                  unit: 'seconds',
                  format: text.secondsLabel,
                  value: settings.readIdleSeconds,
                  defaultValue: MemoSettings.defaultReadIdleSeconds,
                  min: 30,
                  max: 7200,
                  step: 60,
                  onChanged: (v) => _save(
                    context,
                    ref,
                    settings.copyWith(readIdleSeconds: v),
                  ),
                ),
              ),
              _pad(
                NumberSettingTile(
                  title: readKeep.title,
                  what: readKeep.what,
                  raise: readKeep.raise,
                  lower: readKeep.lower,
                  unit: text.unitDays(settings.readKeepDays),
                  value: settings.readKeepDays,
                  defaultValue: MemoSettings.defaultReadKeepDays,
                  min: 1,
                  max: 365,
                  step: 5,
                  onChanged: (v) => _save(
                    context,
                    ref,
                    settings.copyWith(readKeepDays: v),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_sweep_outlined),
                title: Text(text.eraseReadingLabel),
                onTap: () => _eraseReading(context, ref),
              ),
            ],
          ],
        ),
        _SettingsCard(
          title: text.dataCardTitle,
          children: [
            ListTile(
              leading: const Icon(Icons.view_list_rounded),
              title: Text(text.partitionsTitle),
              subtitle: Text(
                memo.custom.map((p) => '${p.name} (${p.count})').join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PartitionsPage()),
              ),
            ),
            ListTile(
              leading: Icon(Icons.restart_alt_rounded, color: theme.colorScheme.error),
              title: Text(text.startOverAction),
              subtitle: Text(text.startOverHint),
              onTap: () => _startOver(context, ref),
            ),
          ],
        ),
      ],
    );
  }
}

/// What the user tells the planner, in numbers and in words: the default
/// wishes or their own, the minutes they have a day, how many suggestions at
/// most, and how many days of their log the AI sees. Saved with the button.
class PlannerWishesSection extends ConsumerStatefulWidget {
  const PlannerWishesSection({super.key});

  @override
  ConsumerState<PlannerWishesSection> createState() => _PlannerWishesState();
}

class _PlannerWishesState extends ConsumerState<PlannerWishesSection> {
  late final TextEditingController _wishes;
  late bool _useDefault;
  late int _minutes;
  late int _items;
  late int _recent;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(memoProvider).planner;
    _wishes = TextEditingController(text: prefs.text);
    _useDefault = prefs.useDefault;
    _minutes = prefs.minutes;
    _items = prefs.maxItems;
    _recent = prefs.recentDays;
  }

  @override
  void dispose() {
    _wishes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = MemoText.of(context);
    final prefs = PlannerPrefs(
      useDefault: _useDefault,
      text: _wishes.text,
      minutes: _minutes,
      maxItems: _items,
      recentDays: _recent,
    );
    try {
      await ref.read(memoProvider.notifier).setPlanner(prefs);
      if (mounted) showAppSnackBar(context, text.saved);
    } catch (_) {
      if (mounted) showAppSnackBar(context, text.storageError, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final minutes = text.settingInfo('plannerMinutes');
    final items = text.settingInfo('plannerItems');
    final recent = text.settingInfo('plannerRecent');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text.plannerPrefsTitle, style: theme.textTheme.titleMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(text.plannerUseDefault),
              value: _useDefault,
              onChanged: (v) => setState(() => _useDefault = v),
            ),
            if (_useDefault) ...[
              Text(text.plannerDefaultIs, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                PlannerPrefs.defaultText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else
              TextField(
                controller: _wishes,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: text.plannerWishesLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            NumberSettingTile(
              title: minutes.title,
              what: minutes.what,
              raise: minutes.raise,
              lower: minutes.lower,
              unit: text.unitMinutes,
              value: _minutes,
              defaultValue: PlannerPrefs.defaultMinutes,
              min: 5,
              max: 1440,
              step: 5,
              onChanged: (v) => setState(() => _minutes = v),
            ),
            NumberSettingTile(
              title: items.title,
              what: items.what,
              raise: items.raise,
              lower: items.lower,
              unit: text.unitSuggestions,
              value: _items,
              defaultValue: PlannerPrefs.defaultMaxItems,
              min: 1,
              max: 30,
              onChanged: (v) => setState(() => _items = v),
            ),
            NumberSettingTile(
              title: recent.title,
              what: recent.what,
              raise: recent.raise,
              lower: recent.lower,
              unit: text.unitDays(_recent),
              value: _recent,
              defaultValue: PlannerPrefs.defaultRecentDays,
              min: 1,
              max: 60,
              onChanged: (v) => setState(() => _recent = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(onPressed: _save, child: Text(text.saveButton)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The user's own partitions: list, create, edit, delete.
class PartitionsPage extends ConsumerWidget {
  const PartitionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = MemoText.of(context);
    final memo = ref.watch(memoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(text.partitionsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: Text(text.partitionNew),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const PartitionEditorPage()),
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              96,
            ),
            children: [
              Text(text.partitionsHelp),
              const SizedBox(height: AppSpacing.md),
              for (final p in memo.custom)
                Card(
                  child: ListTile(
                    title: Text(p.name),
                    subtitle: Text('${p.unit} · ${text.partitionPieces(p.count)}'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PartitionEditorPage(existing: p),
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: text.partitionDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        try {
                          final removed = await ref
                              .read(memoProvider.notifier)
                              .deletePartition(p.id);
                          if (!removed && context.mounted) {
                            showAppSnackBar(context, text.partitionLast, isError: true);
                          }
                        } catch (_) {
                          if (context.mounted) {
                            showAppSnackBar(context, text.storageError, isError: true);
                          }
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Creates or edits one partition: a name, a short word (the "ch" of "ch 3")
/// and where each piece starts, typed as ayahs, pages, juz or surahs.
class PartitionEditorPage extends ConsumerStatefulWidget {
  const PartitionEditorPage({super.key, this.existing});

  final Partition? existing;

  @override
  ConsumerState<PartitionEditorPage> createState() => _PartitionEditorState();
}

class _PartitionEditorState extends ConsumerState<PartitionEditorPage> {
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _starts;

  static final RegExp _separators = RegExp(r'[\n,;]+');
  static final RegExp _unitOk = RegExp(r'^[a-z]{1,8}$');
  static const Set<String> _reserved = {
    's', 'j', 'hz', 'ru', 'p', 'surah', 'juz', 'hizb', 'ruku', 'page', 'pg', 'sura',
  };

  @override
  void initState() {
    super.initState();
    final memo = ref.read(memoProvider);
    final base = widget.existing ?? memo.defaultPartition;
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _unit = TextEditingController(text: widget.existing?.unit ?? '');
    _starts = TextEditingController(
      text: base.starts.map((s) => QuranDivisions.fromIndex(s).key).join('\n'),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _starts.dispose();
    super.dispose();
  }

  /// The starts the text holds, or null when some token cannot be read.
  List<int>? _parse() {
    final memo = ref.read(memoProvider);
    final result = <int>[];
    for (final raw in _starts.text.split(_separators)) {
      final token = raw.trim();
      if (token.isEmpty) continue;
      final parsed = RangeInput.parse(token, memo.partitions);
      final span = parsed.span;
      if (span == null) return null;
      result.add(span.first);
    }
    return result;
  }

  Future<void> _save() async {
    final text = MemoText.of(context);
    final name = _name.text.trim();
    final unit = _unit.text.trim().toLowerCase();
    if (name.isEmpty || unit.isEmpty || !_unitOk.hasMatch(unit)) {
      showAppSnackBar(context, text.partitionNeedName, isError: true);
      return;
    }
    if (_reserved.contains(unit)) {
      showAppSnackBar(context, text.partitionUnitTaken, isError: true);
      return;
    }
    final starts = _parse();
    if (starts == null) {
      showAppSnackBar(context, text.partitionInvalid, isError: true);
      return;
    }
    final id =
        widget.existing?.id ?? 'p${DateTime.now().millisecondsSinceEpoch}';
    final partition = Partition(
      id: id,
      name: name,
      unit: unit,
      kind: PartitionKind.custom,
      starts: starts,
    );
    try {
      await ref.read(memoProvider.notifier).savePartition(partition);
      if (mounted) {
        showAppSnackBar(context, text.saved);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, text.storageError, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final starts = _parse();
    final count = starts == null ? null : Partition.cleanStarts(starts).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? text.partitionNew : text.partitionEdit,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton(onPressed: _save, child: Text(text.saveButton)),
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
            children: [
              TextField(
                controller: _name,
                decoration: InputDecoration(
                  labelText: text.partitionName,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _unit,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: text.partitionUnit,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _starts,
                minLines: 6,
                maxLines: 14,
                autocorrect: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: text.partitionStarts,
                  helperText: text.partitionStartsHelp,
                  helperMaxLines: 3,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                count == null
                    ? text.partitionInvalid
                    : text.partitionPieces(count),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: count == null
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
