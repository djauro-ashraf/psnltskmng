import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/errors/failure.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/features/backup/presentation/widgets/backup_dialogs.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/planning_view_model.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/ai_planner_section.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/planning_draft.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/planning_fields.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/planning_priority_and_shared.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// The field paths of each section: what "Reset to defaults" puts back, and
/// what the screen has a control for.
const _budgetPaths = ['baseBudgetMinutes'];
const _expansionPaths = [
  'constraints.expansionDirectionMode',
  'constraints.expansionTargetPages',
  'constraints.expansionPeriodDays',
  'constraints.maxConsecutiveExpansionDirection',
  'constraints.allowSameDirectionWhenOppositeBlocked',
  'constraints.mainTieBreak',
  'expansion.targetPerDirection',
  'expansion.capacityGate',
  'expansion.allowBeyondTarget',
];
const _timePaths = [
  'time.mMinutesNd',
  'time.mMinutesF3',
  'time.rStartMinutes',
  'time.primeStartFactor',
  'time.rD3CapMinutes',
  'time.rCCapMinutes',
  'time.curveSteepness',
  'time.d3Mode',
  'time.d3HoldUnits',
];
const _sharedPaths = ['time.sharedPageShare'];
const _lPaths = ['constraints.lMonthDays'];
const _priorityPaths = ['priority.order'];
const _planningPaths = [
  'maintainCLeadDays',
  'maxSnapshotGroups',
  'constraints.weekStartsOn',
  'priority.protectMandatoryWork',
  'workload.catchUpStretch',
  'workload.maxDailyMinutes',
  'workload.utilization',
];
const _aiBandPaths = ['workload.aiLowFactor', 'workload.aiHighFactor'];
const _sharedPrefix = 'time.sharedPageShare[';

/// Settings: appearance (theme, language), every planning setting in sections
/// with a message under each field, and the AI planner setup. The planning
/// settings are edited as a draft and saved with Save (disabled while there are
/// problems); they apply from the next plan.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late final PlanningDraft _draft = PlanningDraft(
    ref.read(planningControllerProvider).settings,
  );
  bool _saving = false;

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  Future<bool> _confirm(
    String title,
    String body,
    String action, {
    String? cancel,
  }) async {
    final l10n = context.l10n;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancel ?? l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() => _saving = true);
    try {
      final problems = await ref
          .read(planningViewModelProvider.notifier)
          .updateSettings(_draft.build());
      if (!mounted) return;
      if (problems.isEmpty) {
        _draft.markSaved(ref.read(planningControllerProvider).settings);
        showAppSnackBar(context, l10n.settingsSaved);
      } else {
        showAppSnackBar(context, problems.first.toString(), isError: true);
      }
    } catch (_) {
      if (mounted) showAppSnackBar(context, l10n.settingsSaveFailed, isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetAll() async {
    final l10n = context.l10n;
    final yes = await _confirm(
      l10n.settingsResetAllTitle,
      l10n.settingsResetAllBody,
      l10n.settingsResetAll,
    );
    if (yes) _draft.resetAll();
  }

  /// Problems that no control on the screen shows.
  List<String> _unplaced() {
    const known = {
      ..._budgetPaths,
      ..._expansionPaths,
      ..._timePaths,
      ..._lPaths,
      ..._priorityPaths,
      ..._planningPaths,
      ..._aiBandPaths,
    };
    final shared = ChTable.instance.sharedPages;
    return [
      for (final p in _draft.problems)
        if (!known.contains(p.field) && !_isSharedRow(p.field, shared))
          p.toString(),
    ];
  }

  bool _isSharedRow(String field, List<int> shared) {
    if (!field.startsWith(_sharedPrefix) || !field.endsWith(']')) return false;
    final page = int.tryParse(
      field.substring(_sharedPrefix.length, field.length - 1),
    );
    return page != null && shared.contains(page);
  }

  Widget _section(
    BuildContext context,
    String title,
    List<String> paths,
    List<Widget> children,
  ) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ExpansionTile(
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...children,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _draft.resetPaths(paths),
              child: Text(l10n.settingsResetSection),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final load = ref.watch(planningViewModelProvider);
    final failedReason = load is PlanningLoadFailed ? load.reason : null;
    final failed = failedReason != null;

    return ListenableBuilder(
      listenable: _draft,
      builder: (context, _) {
        final canSave = !failed && _draft.valid && _draft.dirty && !_saving;
        return PopScope(
          canPop: !_draft.dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final leave = await _confirm(
              l10n.settingsDiscardTitle,
              l10n.settingsDiscardBody,
              l10n.settingsDiscard,
              cancel: l10n.settingsKeepEditing,
            );
            if (leave && context.mounted) {
              _draft.markSaved(ref.read(planningControllerProvider).settings);
              Navigator.of(context).maybePop();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.settingsTitle),
              actions: [
                IconButton(
                  tooltip: l10n.settingsResetAll,
                  onPressed: failed ? null : _resetAll,
                  icon: const Icon(Icons.restart_alt_rounded),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: canSave ? _save : null,
                    child: Text(l10n.settingsSave),
                  ),
                ),
              ],
            ),
            body: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoints.formMaxWidth,
                ),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: [
                    if (failed)
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Text(
                            '${l10n.settingsDisabled}\n${l10n.failedMessage(failedReason)}',
                          ),
                        ),
                      ),
                    IgnorePointer(
                      ignoring: failed,
                      child: Opacity(
                        opacity: failed ? 0.4 : 1,
                        child: _body(context, l10n),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    final unplaced = _unplaced();
    final d = _draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AppearanceSection(),
        const SizedBox(height: AppSpacing.md),
        const _BackupSection(),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(l10n.settingsPlanningNote)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (!d.valid)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              l10n.settingsFixProblems,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        for (final text in unplaced)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              text,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        _section(context, l10n.settingsSectionBudget, _budgetPaths, [
          NumberFieldTile(
            draft: d,
            path: 'baseBudgetMinutes',
            label: l10n.fieldBaseBudget,
            step: 15,
            min: 0,
          ),
        ]),
        _section(context, l10n.settingsSectionExpansion, _expansionPaths, [
          ChoiceFieldTile(
            draft: d,
            path: 'constraints.expansionDirectionMode',
            label: l10n.fieldDirectionMode,
            options: {
              'both': l10n.modeBoth,
              'forwardOnly': l10n.modeForwardOnly,
              'backwardOnly': l10n.modeBackwardOnly,
            },
          ),
          NumberFieldTile(
            draft: d,
            path: 'constraints.expansionTargetPages',
            label: l10n.fieldExpansionTarget,
            isInt: true,
            min: 0,
          ),
          NumberFieldTile(
            draft: d,
            path: 'constraints.expansionPeriodDays',
            label: l10n.fieldExpansionPeriod,
            isInt: true,
            min: 1,
          ),
          NumberFieldTile(
            draft: d,
            path: 'constraints.maxConsecutiveExpansionDirection',
            label: l10n.fieldMaxInRow,
            isInt: true,
            min: 1,
          ),
          SwitchFieldTile(
            draft: d,
            path: 'constraints.allowSameDirectionWhenOppositeBlocked',
            label: l10n.fieldAllowSameDirection,
          ),
          ChoiceFieldTile(
            draft: d,
            path: 'constraints.mainTieBreak',
            label: l10n.fieldMainTieBreak,
            options: {
              'lowerPages': l10n.tieLowerPages,
              'higherPages': l10n.tieHigherPages,
            },
          ),
          NumberFieldTile(
            draft: d,
            path: 'expansion.targetPerDirection',
            label: l10n.fieldTargetPerDirection,
            isInt: true,
            min: 0,
            nullable: true,
          ),
          SwitchFieldTile(
            draft: d,
            path: 'expansion.capacityGate',
            label: l10n.fieldCapacityGate,
          ),
          SwitchFieldTile(
            draft: d,
            path: 'expansion.allowBeyondTarget',
            label: l10n.fieldAllowBeyondTarget,
          ),
        ]),
        Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ExpansionTile(
            leading: const Icon(Icons.tune_rounded),
            title: Text(
              'Advanced Algorithm Tuning',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: const Text(
              'Time models, priority ordering, and workload stretch',
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _section(context, l10n.settingsSectionTime, _timePaths, [
          NumberFieldTile(
            draft: d,
            path: 'time.mMinutesNd',
            label: l10n.fieldMMinutesNd,
            step: 5,
            min: 0,
          ),
          NumberFieldTile(
            draft: d,
            path: 'time.mMinutesF3',
            label: l10n.fieldMMinutesF3,
            step: 5,
            min: 0,
          ),
          NumberFieldTile(
            draft: d,
            path: 'time.rStartMinutes',
            label: l10n.fieldRStart,
            step: 1,
            min: 0,
          ),
          NumberFieldTile(
            draft: d,
            path: 'time.primeStartFactor',
            label: l10n.fieldPrimeFactor,
            step: 0.05,
            min: 0,
          ),
          NumberFieldTile(
            draft: d,
            path: 'time.rD3CapMinutes',
            label: l10n.fieldRD3Cap,
            step: 1,
            min: 0,
          ),
          NumberFieldTile(
            draft: d,
            path: 'time.rCCapMinutes',
            label: l10n.fieldRCCap,
            step: 1,
            min: 0,
          ),
          NumberFieldTile(
            draft: d,
            path: 'time.curveSteepness',
            label: l10n.fieldCurve,
            step: 0.5,
            min: 0,
          ),
          ChoiceFieldTile(
            draft: d,
            path: 'time.d3Mode',
            label: l10n.fieldD3Mode,
            options: {'cap': l10n.d3ModeCap, 'cont': l10n.d3ModeCont},
          ),
          NumberFieldTile(
            draft: d,
            path: 'time.d3HoldUnits',
            label: l10n.fieldD3Hold,
            isInt: true,
            min: 0,
          ),
        ]),
        _section(context, l10n.settingsSectionShared, _sharedPaths, [
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.sharedOpen),
            subtitle: Text(l10n.sharedCustomCount(d.customShareCount)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SharedPagesScreen(draft: d),
              ),
            ),
          ),
          if (d.problems.any((p) => p.field.startsWith(_sharedPrefix)))
            fieldError(
              context,
              l10n.sharedProblems(
                d.problems.where((p) => p.field.startsWith(_sharedPrefix)).length,
              ),
            ),
        ]),
        _section(context, l10n.settingsSectionL, _lPaths, [
          NumberFieldTile(
            draft: d,
            path: 'constraints.lMonthDays',
            label: l10n.fieldLDays,
            isInt: true,
            min: 1,
          ),
        ]),
        _section(context, l10n.settingsSectionPriorities, _priorityPaths, [
          PriorityListTile(draft: d),
        ]),
        _section(context, l10n.settingsSectionPlanning, _planningPaths, [
          NumberFieldTile(
            draft: d,
            path: 'maintainCLeadDays',
            label: l10n.fieldMaintainLead,
            isInt: true,
            min: 0,
          ),
          NumberFieldTile(
            draft: d,
            path: 'maxSnapshotGroups',
            label: l10n.fieldMaxSnapshotGroups,
            isInt: true,
            min: 1,
          ),
          ChoiceFieldTile(
            draft: d,
            path: 'constraints.weekStartsOn',
            label: l10n.fieldWeekStartsOn,
            options: {
              1: l10n.weekdayMon,
              2: l10n.weekdayTue,
              3: l10n.weekdayWed,
              4: l10n.weekdayThu,
              5: l10n.weekdayFri,
              6: l10n.weekdaySat,
              7: l10n.weekdaySun,
            },
          ),
          SwitchFieldTile(
            draft: d,
            path: 'priority.protectMandatoryWork',
            label: l10n.fieldProtectMandatory,
          ),
          NumberFieldTile(
            draft: d,
            path: 'workload.catchUpStretch',
            label: l10n.fieldCatchUpStretch,
            step: 0.1,
            min: 1,
          ),
          NumberFieldTile(
            draft: d,
            path: 'workload.maxDailyMinutes',
            label: l10n.fieldMaxDaily,
            step: 15,
            min: 0,
            nullable: true,
          ),
            NumberFieldTile(
              draft: d,
              path: 'workload.utilization',
              label: l10n.fieldUtilization,
              step: 0.05,
              min: 0,
            ),
          ]),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: ExpansionTile(
            title: Text(
              l10n.settingsSectionAi,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AiPlannerSection(),
              NumberFieldTile(
                draft: d,
                path: 'workload.aiLowFactor',
                label: l10n.fieldAiLowFactor,
                step: 0.05,
                min: 0.05,
              ),
              NumberFieldTile(
                draft: d,
                path: 'workload.aiHighFactor',
                label: l10n.fieldAiHighFactor,
                step: 0.1,
                min: 1,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => d.resetPaths(_aiBandPaths),
                  child: Text(l10n.settingsResetSection),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Theme and language (unchanged from before).
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  Future<void> _apply(BuildContext context, Future<Failure?> action) async {
    final failure = await action;
    if (failure != null && context.mounted) {
      showFailureSnackBar(context, failure);
    }
  }

  String _themeLabel(AppLocalizations l10n, AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => l10n.settingsThemeSystem,
      AppThemeMode.light => l10n.settingsThemeLight,
      AppThemeMode.dark => l10n.settingsThemeDark,
    };
  }

  IconData _themeIcon(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => Icons.brightness_auto_outlined,
      AppThemeMode.light => Icons.light_mode_outlined,
      AppThemeMode.dark => Icons.dark_mode_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsThemeSection, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<AppThemeMode>(
          showSelectedIcon: false,
          segments: [
            for (final mode in AppThemeMode.values)
              ButtonSegment<AppThemeMode>(
                value: mode,
                icon: Icon(_themeIcon(mode)),
                label: Text(_themeLabel(l10n, mode)),
              ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (selection) =>
              _apply(context, viewModel.setThemeMode(selection.first)),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.settingsLanguageSection, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: Text(l10n.settingsLanguageSystem),
              selected: settings.localeCode == null,
              onSelected: (_) => _apply(context, viewModel.setLocaleCode(null)),
            ),
            // Built from the generated locales: adding an ARB file adds a chip.
            for (final locale in AppLocalizations.supportedLocales)
              ChoiceChip(
                label: Text(lookupAppLocalizations(locale).languageName),
                selected: settings.localeCode == locale.languageCode,
                onSelected: (_) => _apply(
                  context,
                  viewModel.setLocaleCode(locale.languageCode),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appSettings = ref.watch(settingsViewModelProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(
                    Icons.cloud_sync_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Cloud Backup & Device Sync',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Keep your learning data safe with Google Drive, or export and import backups across devices.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                appSettings.googleDriveConnected
                    ? Icons.check_circle_rounded
                    : Icons.cloud_off_rounded,
                color: appSettings.googleDriveConnected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: Text(
                appSettings.googleDriveConnected
                    ? 'Google Drive Connected (${appSettings.googleDriveEmail ?? 'Active'})'
                    : 'Google Drive Disconnected',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Auto-backup: ${appSettings.backupFrequency} • Last synced: ${appSettings.lastBackupTime != null ? appSettings.lastBackupTime!.split('T')[0] : 'Never'}',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => showGoogleDriveDialog(context, ref),
                child: Text(
                  appSettings.googleDriveConnected ? 'Manage' : 'Connect',
                ),
              ),
            ),
            const Divider(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showExportBackupDialog(context, ref),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export Backup (JSON)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showImportBackupDialog(context, ref),
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Import Backup (JSON)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
