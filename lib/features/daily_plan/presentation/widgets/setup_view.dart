import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/rules/q_setup.dart';
import 'package:personaltskmng/features/backup/presentation/widgets/backup_dialogs.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/planning_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/today_view_model.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/page_state_widgets.dart';

// ---------------------------------------------------------------------------
// Range parsing utilities — supports "1-50, 75, 82-100" style input.
// ---------------------------------------------------------------------------

/// A single contiguous page range with inclusive bounds.
class _PageSpan {
  const _PageSpan(this.from, this.to);
  final int from;
  final int to;

  /// Number of pages in this span.
  int get count => to - from + 1;

  /// Whether [page] is inside.
  bool contains(int page) => page >= from && page <= to;

  @override
  String toString() => from == to ? '$from' : '$from–$to';
}

/// Parses a user string like "1-50, 75, 82-100" into a sorted, merged list of
/// [_PageSpan]s. Returns null when the input is empty or has no valid tokens.
List<_PageSpan>? _parseSpans(String text) {
  if (text.trim().isEmpty) return null;
  final raw = <_PageSpan>[];
  // Split on comma, semicolon, newline or whitespace-separated chunks.
  final tokens = text.split(RegExp(r'[,;\n]+'));
  for (final tok in tokens) {
    final t = tok.trim();
    if (t.isEmpty) continue;
    final rangeMatch = RegExp(r'^(\d+)\s*[-–—]\s*(\d+)$').firstMatch(t);
    if (rangeMatch != null) {
      final a = int.parse(rangeMatch.group(1)!);
      final b = int.parse(rangeMatch.group(2)!);
      if (a <= b && a >= 1 && b <= ChTable.totalPages) {
        raw.add(_PageSpan(a, b));
      }
    } else {
      final single = int.tryParse(t);
      if (single != null && single >= 1 && single <= ChTable.totalPages) {
        raw.add(_PageSpan(single, single));
      }
    }
  }
  if (raw.isEmpty) return null;
  // Sort and merge overlapping / adjacent spans.
  raw.sort((a, b) => a.from.compareTo(b.from));
  final merged = <_PageSpan>[raw.first];
  for (var i = 1; i < raw.length; i++) {
    final prev = merged.last;
    final cur = raw[i];
    if (cur.from <= prev.to + 1) {
      merged[merged.length - 1] = _PageSpan(prev.from, cur.to > prev.to ? cur.to : prev.to);
    } else {
      merged.add(cur);
    }
  }
  return merged;
}

/// Total pages across a list of spans.
int _spanCount(List<_PageSpan>? spans) {
  if (spans == null) return 0;
  return spans.fold(0, (sum, s) => sum + s.count);
}

/// Pretty-print spans for display: "1–50, 75, 82–100".
String _spansSummary(List<_PageSpan>? spans) {
  if (spans == null || spans.isEmpty) return '—';
  return spans.map((s) => s.toString()).join(', ');
}

/// Returns spans from [source] that are NOT covered by [exclude].
List<_PageSpan> _subtractSpans(List<_PageSpan> source, List<_PageSpan>? exclude) {
  if (exclude == null || exclude.isEmpty) return List.of(source);
  // Build a set of excluded page numbers (fine for ≤604 pages).
  final ex = <int>{};
  for (final s in exclude) {
    for (var p = s.from; p <= s.to; p++) {
      ex.add(p);
    }
  }
  // Walk through source and collect non-excluded runs.
  final result = <_PageSpan>[];
  for (final s in source) {
    int? runStart;
    for (var p = s.from; p <= s.to; p++) {
      if (!ex.contains(p)) {
        runStart ??= p;
      } else if (runStart != null) {
        result.add(_PageSpan(runStart, p - 1));
        runStart = null;
      }
    }
    if (runStart != null) {
      result.add(_PageSpan(runStart, s.to));
    }
  }
  return result;
}

// ---------------------------------------------------------------------------
// Friendly "days since review" labels.
// ---------------------------------------------------------------------------

enum _Recency {
  yesterday('Ready to review today (last reviewed yesterday or earlier)', 1),
  today('Already reviewed earlier today', 0),
  lastWeek('Within the last week (2–7 days ago)', 3),
  fewWeeks('A few weeks ago', 14),
  monthAgo('A month or more ago', 30),
  longAgo('Not sure / a long time ago', 45);

  const _Recency(this.label, this.days);
  final String label;
  final int days;
}

// ---------------------------------------------------------------------------
// The wizard step index.
// ---------------------------------------------------------------------------

enum _Step {
  budget,
  allMemorized,
  wellPracticed,
  somewhatFamiliar,
  forgotten,
  review,
}

// ---------------------------------------------------------------------------
// Setup funnel wizard.
// ---------------------------------------------------------------------------

/// First-run setup, shown instead of Today when nothing is stored.
/// Uses a step-by-step funnel wizard that asks natural questions.
class SetupView extends ConsumerStatefulWidget {
  const SetupView({super.key});

  @override
  ConsumerState<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends ConsumerState<SetupView> {
  _Step _currentStep = _Step.budget;
  bool _busy = false;
  final List<String> _problems = [];

  // Step 1: Budget
  final TextEditingController _minutes = TextEditingController(
    text: '${PlanningSettings.defaultBaseBudgetMinutes.round()}',
  );

  // Step 2: All memorized pages
  final TextEditingController _allMemorizedCtrl = TextEditingController();
  _Recency _allRecency = _Recency.yesterday;

  // Step 3: Well-practiced (D3) — subset of allMemorized
  final TextEditingController _d3Ctrl = TextEditingController();
  _Recency _d3Recency = _Recency.yesterday;

  // Step 4: Somewhat familiar (D2) — subset of remaining
  final TextEditingController _d2Ctrl = TextEditingController();
  _Recency _d2Recency = _Recency.yesterday;

  // Step 5: Forgotten (F3) — pages that were once memorized but lost
  final TextEditingController _forgottenCtrl = TextEditingController();

  @override
  void dispose() {
    _minutes.dispose();
    _allMemorizedCtrl.dispose();
    _d3Ctrl.dispose();
    _d2Ctrl.dispose();
    _forgottenCtrl.dispose();
    super.dispose();
  }

  // ------ Derived data ------

  List<_PageSpan>? get _allSpans => _parseSpans(_allMemorizedCtrl.text);
  List<_PageSpan>? get _d3Spans => _parseSpans(_d3Ctrl.text);
  List<_PageSpan>? get _d2Spans => _parseSpans(_d2Ctrl.text);
  List<_PageSpan>? get _forgottenSpans => _parseSpans(_forgottenCtrl.text);

  /// D1 = allMemorized minus D3 minus D2 minus forgotten
  List<_PageSpan> get _d1Spans {
    final all = _allSpans;
    if (all == null) return [];
    var remaining = _subtractSpans(all, _d3Spans);
    remaining = _subtractSpans(remaining, _d2Spans);
    remaining = _subtractSpans(remaining, _forgottenSpans);
    return remaining;
  }

  double? _budget() {
    final value = double.tryParse(_minutes.text.trim().replaceAll(',', '.'));
    return value != null && value > 0 ? value : null;
  }

  // ------ Navigation ------

  void _next() {
    setState(() {
      _problems.clear();
      switch (_currentStep) {
        case _Step.budget:
          if (_budget() == null) {
            _problems.add('Please enter a valid number of minutes (above 0).');
            return;
          }
          _currentStep = _Step.allMemorized;
        case _Step.allMemorized:
          _currentStep = _Step.wellPracticed;
        case _Step.wellPracticed:
          _currentStep = _Step.somewhatFamiliar;
        case _Step.somewhatFamiliar:
          _currentStep = _Step.forgotten;
        case _Step.forgotten:
          _currentStep = _Step.review;
        case _Step.review:
          return; // handled by _finish
      }
    });
  }

  void _back() {
    setState(() {
      _problems.clear();
      switch (_currentStep) {
        case _Step.budget:
          return;
        case _Step.allMemorized:
          _currentStep = _Step.budget;
        case _Step.wellPracticed:
          _currentStep = _Step.allMemorized;
        case _Step.somewhatFamiliar:
          _currentStep = _Step.wellPracticed;
        case _Step.forgotten:
          _currentStep = _Step.somewhatFamiliar;
        case _Step.review:
          _currentStep = _Step.forgotten;
      }
    });
  }

  // ------ Build SetupRows ------

  List<SetupRow> _buildRows() {
    final rows = <SetupRow>[];
    // D3 ranges
    final d3 = _d3Spans;
    if (d3 != null) {
      for (final s in d3) {
        rows.add(SetupRow(
          from: s.from,
          to: s.to,
          state: PageState.d3,
          daysSinceR: _d3Recency.days,
        ));
      }
    }
    // D2 ranges
    final d2 = _d2Spans;
    if (d2 != null) {
      for (final s in d2) {
        rows.add(SetupRow(
          from: s.from,
          to: s.to,
          state: PageState.d2,
          daysSinceR: _d2Recency.days,
        ));
      }
    }
    // D1 = remainder of allMemorized minus D3, D2, forgotten
    for (final s in _d1Spans) {
      rows.add(SetupRow(
        from: s.from,
        to: s.to,
        state: PageState.d1,
        daysSinceR: _allRecency.days,
      ));
    }
    // F3 ranges
    final f3 = _forgottenSpans;
    if (f3 != null) {
      for (final s in f3) {
        rows.add(SetupRow(
          from: s.from,
          to: s.to,
          state: PageState.f3,
          daysSinceR: 45,
        ));
      }
    }
    return rows;
  }

  String _problemText(AppLocalizations l10n, SetupProblem p) {
    final row = p.row ?? 0;
    return switch (p.kind) {
      SetupProblemKind.stateNotAllowed => l10n.setupProblemState(row),
      SetupProblemKind.fromAfterTo => l10n.setupProblemFromAfterTo(row),
      SetupProblemKind.pageOutOfBounds => l10n.setupProblemOutOfBounds(
        row,
        p.value ?? 0,
      ),
      SetupProblemKind.progressNegative =>
        l10n.setupProblemProgressNegative(row),
      SetupProblemKind.progressTooHigh => l10n.setupProblemProgressTooHigh(
        row,
        p.value ?? 0,
        p.max ?? 0,
      ),
      SetupProblemKind.progressNotForState =>
        l10n.setupProblemProgressNotForState(row),
      SetupProblemKind.daysNegative => l10n.setupProblemDaysNegative(row),
      SetupProblemKind.overlap => l10n.setupProblemOverlap(
        row,
        p.otherRow ?? 0,
      ),
      SetupProblemKind.invalidQ => l10n.setupProblemInvalidQ(p.detail ?? ''),
    };
  }

  // ------ Finish ------

  Future<void> _finish({required bool withRows}) async {
    final l10n = context.l10n;
    final budget = _budget();
    if (budget == null) {
      setState(() {
        _problems
          ..clear()
          ..add(l10n.setupBudgetInvalid);
      });
      return;
    }

    final rows = withRows ? _buildRows() : <SetupRow>[];

    final controller = ref.read(planningControllerProvider);
    final today = Day.fromDateTime(ref.read(todayClockProvider)());
    final built = QSetup.build(
      id: StoredState.defaultQId,
      rows: rows,
      today: today,
      constraints: controller.settings.constraints,
    );
    switch (built) {
      case QSetupProblems(:final problems):
        setState(() {
          _problems
            ..clear()
            ..addAll([for (final p in problems) _problemText(l10n, p)]);
        });
      case QSetupOk(:final q):
        setState(() {
          _busy = true;
          _problems.clear();
        });
        List<SettingsProblem> saved;
        try {
          saved = await ref
              .read(planningViewModelProvider.notifier)
              .completeSetup(q, budget);
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _busy = false;
            _problems.add(l10n.setupSaveFailed);
          });
          return;
        }
        if (!mounted) return;
        if (saved.isNotEmpty) {
          setState(() {
            _busy = false;
            _problems.add(l10n.setupBudgetInvalid);
          });
          return;
        }
        // Auto-generate the first plan so the user sees it immediately.
        try {
          await ref.read(todayViewModelProvider.notifier).makePlan();
        } catch (_) {
          // Non-critical: the user can press "Make a plan" manually.
        }
    }
  }

  // ------ Advanced mode ------

  Future<void> _pasteRangesDialog() async {
    final textCtrl = TextEditingController(
      text: '1-50: D3\n51-80: D2\n81-100: D1',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.content_paste_rounded),
            SizedBox(width: AppSpacing.sm),
            Text('Paste Multiple Ranges'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter ranges in line format, e.g.:\n'
                '1-50: D3\n'
                '51-80: D2\n'
                '81-100: D1\n\n'
                'You can also use single pages: 75: D3',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: textCtrl,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: '1-100: D3',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final lines = textCtrl.text.split('\n');
              // Parse into the funnel fields.
              final d3Ranges = <String>[];
              final d2Ranges = <String>[];
              final d1Ranges = <String>[];
              final f3Ranges = <String>[];
              final allRanges = <String>[];
              final regex =
                  RegExp(r'(\d+)\s*[-–]?\s*(\d*)\s*(?::\s*([dDfF]\d))?');
              for (final line in lines) {
                final match = regex.firstMatch(line.trim());
                if (match != null) {
                  final f = match.group(1)!;
                  final t = match.group(2)?.isNotEmpty == true
                      ? match.group(2)!
                      : f;
                  final stateStr = match.group(3)?.toLowerCase() ?? 'd3';
                  final rangeStr = f == t ? f : '$f-$t';
                  allRanges.add(rangeStr);
                  switch (stateStr) {
                    case 'd3':
                      d3Ranges.add(rangeStr);
                    case 'd2':
                      d2Ranges.add(rangeStr);
                    case 'd1':
                      d1Ranges.add(rangeStr);
                    case 'f3':
                      f3Ranges.add(rangeStr);
                  }
                }
              }
              if (allRanges.isNotEmpty) {
                setState(() {
                  // All memorized = all non-F3 ranges
                  final memorized = [...d3Ranges, ...d2Ranges, ...d1Ranges];
                  _allMemorizedCtrl.text = memorized.join(', ');
                  _d3Ctrl.text = d3Ranges.join(', ');
                  _d2Ctrl.text = d2Ranges.join(', ');
                  _forgottenCtrl.text = f3Ranges.join(', ');
                  _currentStep = _Step.review;
                });
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  // ------ Build ------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stepIndex = _Step.values.indexOf(_currentStep);
    final totalSteps = _Step.values.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.setupTitle),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formMaxWidth,
          ),
          child: Column(
            children: [
              // One segment per step; the ones reached so far are filled.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                child: _StepIndicator(current: stepIndex, total: totalSteps),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${stepIndex + 1} of $totalSteps',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_currentStep != _Step.budget)
                      TextButton.icon(
                        onPressed: _busy ? null : _back,
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Back'),
                      ),
                  ],
                ),
              ),
              // Step content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  children: [
                    switch (_currentStep) {
                      _Step.budget => _buildBudgetStep(theme),
                      _Step.allMemorized => _buildAllMemorizedStep(theme),
                      _Step.wellPracticed => _buildWellPracticedStep(theme),
                      _Step.somewhatFamiliar =>
                        _buildSomewhatFamiliarStep(theme),
                      _Step.forgotten => _buildForgottenStep(theme),
                      _Step.review => _buildReviewStep(theme),
                    },
                    if (_problems.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      for (final text in _problems)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            text,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                    ],
                    if (_busy) ...[
                      const SizedBox(height: AppSpacing.md),
                      const LinearProgressIndicator(),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Setting up your study plan…',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // Step builders
  // ========================================================================

  // ------ Step 1: Budget ------

  Widget _buildBudgetStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        _stepHeader(
          theme,
          icon: Icons.timer_rounded,
          title: 'How much time can you study daily?',
          subtitle:
              'Set the number of minutes you can spend each day on review '
              'and memorization. You can change this anytime in Settings.',
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final min in const [15, 30, 45, 60, 90])
              ActionChip(
                label: Text('$min min'),
                onPressed: _busy
                    ? null
                    : () => setState(() => _minutes.text = '$min'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _minutes,
          enabled: !_busy,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Minutes per day',
            suffixText: 'minutes',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Restore backup options: Google Drive, a file from storage, pasted text
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Already have data?',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'If you used this app before and have a backup, you can '
                  'restore it instead of setting up from scratch.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: _busy
                          ? null
                          : () => showGoogleDriveRestoreDialog(context, ref),
                      icon: const Icon(Icons.cloud_download_outlined),
                      label: const Text('Restore from Google Drive'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => showImportBackupDialog(
                              context,
                              ref,
                              chooseFileFirst: true,
                            ),
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('Import from file'),
                    ),
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => showImportBackupDialog(context, ref),
                      icon: const Icon(Icons.content_paste_rounded),
                      label: const Text('Paste backup text'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _navigationButtons(
          onNext: _next,
          showSkip: false,
        ),
      ],
    );
  }

  // ------ Step 2: All memorized pages ------

  Widget _buildAllMemorizedStep(ThemeData theme) {
    final allCount = _spanCount(_allSpans);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        _stepHeader(
          theme,
          icon: Icons.menu_book_rounded,
          title: 'Which pages have you memorized?',
          subtitle:
              'Enter the pages you have studied at least once. '
              'Everything not listed will start as new (unmemorized).\n\n'
              'You can enter ranges, single pages, or mix them:\n'
              '• "1-200" for a range\n'
              '• "1-50, 75, 82-100" for mixed\n'
              '• "1-20, 25, 30-50" etc.',
        ),
        const SizedBox(height: AppSpacing.md),
        // Quick presets
        Text('Quick presets:', style: theme.textTheme.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ActionChip(
              avatar: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('First Juz (1–20)'),
              onPressed: () =>
                  setState(() => _allMemorizedCtrl.text = '1-20'),
            ),
            ActionChip(
              label: const Text('1–50'),
              onPressed: () =>
                  setState(() => _allMemorizedCtrl.text = '1-50'),
            ),
            ActionChip(
              label: const Text('1–100'),
              onPressed: () =>
                  setState(() => _allMemorizedCtrl.text = '1-100'),
            ),
            ActionChip(
              label: const Text('1–200'),
              onPressed: () =>
                  setState(() => _allMemorizedCtrl.text = '1-200'),
            ),
            ActionChip(
              label: const Text('All (1–604)'),
              onPressed: () =>
                  setState(() => _allMemorizedCtrl.text = '1-604'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _allMemorizedCtrl,
          enabled: !_busy,
          decoration: const InputDecoration(
            labelText: 'Pages memorized',
            hintText: 'e.g. 1-200 or 1-50, 75, 82-100',
            helperText: 'Use commas to separate ranges and single pages.',
            helperMaxLines: 2,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (allCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _infoChip(theme, '$allCount pages selected'),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text(
          'When did you last review these pages?',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildRecencySelector(
          selected: _allRecency,
          onChanged: (v) => setState(() => _allRecency = v),
        ),
        const SizedBox(height: AppSpacing.xl),
        _navigationButtons(
          onNext: _next,
          skipLabel: 'Skip — I haven\'t memorized anything yet',
          onSkip: () => _finish(withRows: false),
        ),
      ],
    );
  }

  // ------ Step 3: Well-practiced (D3) ------

  Widget _buildWellPracticedStep(ThemeData theme) {
    final allSpans = _allSpans;
    if (allSpans == null || allSpans.isEmpty) {
      // User didn't enter any memorized pages — skip to review.
      WidgetsBinding.instance.addPostFrameCallback((_) => _next());
      return const SizedBox.shrink();
    }

    final allSummary = _spansSummary(allSpans);
    final d3Count = _spanCount(_d3Spans);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        _stepHeader(
          theme,
          icon: Icons.star_rounded,
          title: 'Which ones are well-practiced?',
          subtitle:
              'Of the pages you memorized ($allSummary), which ones '
              'have you revised many times and feel confident about?\n\n'
              'These will start at Stage 3 (Solid) — the highest level '
              'you can claim. Leave empty if none are that strong.',
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _d3Ctrl,
          enabled: !_busy,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Well-practiced pages (optional)',
            hintText: 'e.g. 1-50, 75, 82-100',
            helperText: 'Ranges, single pages, or a mix — separated by commas.',
            helperMaxLines: 2,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (d3Count > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _infoChip(theme, '$d3Count pages → Stage 3 (Solid)'),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (d3Count > 0) ...[
          Text(
            'When did you last review these strong pages?',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildRecencySelector(
            selected: _d3Recency,
            onChanged: (v) => setState(() => _d3Recency = v),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _navigationButtons(
          onNext: _next,
          skipLabel: 'Skip — all at the same level',
          onSkip: () {
            setState(() {
              _d3Ctrl.clear();
              _d2Ctrl.clear();
            });
            _next();
            _next(); // skip D2 as well
          },
        ),
      ],
    );
  }

  // ------ Step 4: Somewhat familiar (D2) ------

  Widget _buildSomewhatFamiliarStep(ThemeData theme) {
    final allSpans = _allSpans;
    if (allSpans == null || allSpans.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _next());
      return const SizedBox.shrink();
    }

    // Show what remains after D3 is removed.
    final remaining = _subtractSpans(allSpans, _d3Spans);
    if (remaining.isEmpty) {
      // Everything is D3, skip.
      WidgetsBinding.instance.addPostFrameCallback((_) => _next());
      return const SizedBox.shrink();
    }

    final remainingSummary = _spansSummary(remaining);
    final d2Count = _spanCount(_d2Spans);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        _stepHeader(
          theme,
          icon: Icons.trending_up_rounded,
          title: 'Which ones are somewhat familiar?',
          subtitle:
              'Of the remaining pages ($remainingSummary), which ones have '
              'you revised a few times? They\'re not rock-solid, but you '
              'know them reasonably well.\n\n'
              'These will start at Stage 2 (Familiar). Everything left '
              'after this will be Stage 1 (Freshly Started).',
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _d2Ctrl,
          enabled: !_busy,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Somewhat familiar pages (optional)',
            hintText: 'e.g. 51-120, 135',
            helperText: 'Ranges, single pages, or a mix — separated by commas.',
            helperMaxLines: 2,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (d2Count > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _infoChip(theme, '$d2Count pages → Stage 2 (Familiar)'),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (d2Count > 0) ...[
          Text(
            'When did you last review these pages?',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xs),
          _buildRecencySelector(
            selected: _d2Recency,
            onChanged: (v) => setState(() => _d2Recency = v),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        _navigationButtons(onNext: _next),
      ],
    );
  }

  // ------ Step 5: Forgotten ------

  Widget _buildForgottenStep(ThemeData theme) {
    final forgottenCount = _spanCount(_forgottenSpans);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        _stepHeader(
          theme,
          icon: Icons.history_rounded,
          title: 'Any forgotten pages?',
          subtitle:
              'Have you memorized pages in the past that you\'ve '
              'completely forgotten? These will need re-memorization.\n\n'
              'These don\'t have to be from the ranges above — they '
              'can be any pages you once knew but lost.',
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _forgottenCtrl,
          enabled: !_busy,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Forgotten pages (optional)',
            hintText: 'e.g. 181-200, 55',
            helperText: 'Leave empty if you haven\'t forgotten anything.',
            helperMaxLines: 2,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (forgottenCount > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          _infoChip(theme, '$forgottenCount pages → Needs Recovery'),
        ],
        const SizedBox(height: AppSpacing.xl),
        _navigationButtons(onNext: _next),
      ],
    );
  }

  // ------ Step 6: Review ------

  Widget _buildReviewStep(ThemeData theme) {
    final d3Count = _spanCount(_d3Spans);
    final d2Count = _spanCount(_d2Spans);
    final d1 = _d1Spans;
    final d1Count = _spanCount(d1.isEmpty ? null : d1);
    final f3Count = _spanCount(_forgottenSpans);
    final ndCount = ChTable.totalPages - d3Count - d2Count - d1Count - f3Count;
    final totalConfigured = d3Count + d2Count + d1Count + f3Count;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.md),
        _stepHeader(
          theme,
          icon: Icons.checklist_rounded,
          title: 'Review your setup',
          subtitle: 'Here\'s a summary of how your pages will be organized. '
              'Go back to adjust anything before confirming.',
        ),
        const SizedBox(height: AppSpacing.lg),
        // Summary table
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _summaryRow(
                  theme,
                  state: PageState.d3,
                  label: 'Stage 3 — Solid',
                  pages: _spansSummary(_d3Spans),
                  count: d3Count,
                ),
                const Divider(height: 1),
                _summaryRow(
                  theme,
                  state: PageState.d2,
                  label: 'Stage 2 — Familiar',
                  pages: _spansSummary(_d2Spans),
                  count: d2Count,
                ),
                const Divider(height: 1),
                _summaryRow(
                  theme,
                  state: PageState.d1,
                  label: 'Stage 1 — Freshly Started',
                  pages: _spansSummary(d1.isEmpty ? null : d1),
                  count: d1Count,
                ),
                const Divider(height: 1),
                _summaryRow(
                  theme,
                  state: PageState.f3,
                  label: 'Needs Recovery',
                  pages: _spansSummary(_forgottenSpans),
                  count: f3Count,
                ),
                const Divider(height: 1),
                _summaryRow(
                  theme,
                  state: PageState.nd,
                  label: 'New (unmemorized)',
                  pages: '',
                  count: ndCount,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(Icons.timer_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Daily budget: ${_minutes.text} minutes • '
                    '$totalConfigured pages configured',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Advanced option
        ExpansionTile(
          title: const Text('Advanced Options'),
          leading: const Icon(Icons.tune_rounded),
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pasteRangesDialog,
                    icon: const Icon(Icons.content_paste_rounded),
                    label: const Text('Import from text (advanced)'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        // Final buttons
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _busy ? null : () => _finish(withRows: true),
            icon: const Icon(Icons.rocket_launch_rounded),
            label: const Text('Start My Study Plan'),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _busy ? null : () => _finish(withRows: false),
            child: const Text('Start with nothing learned'),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // Shared widgets
  // ========================================================================

  Widget _stepHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.control + 2),
          ),
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _infoChip(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _buildRecencySelector({
    required _Recency selected,
    required ValueChanged<_Recency> onChanged,
  }) {
    return Card(
      child: RadioGroup<_Recency>(
        groupValue: selected,
        onChanged: (v) {
          if (!_busy && v != null) onChanged(v);
        },
        child: Column(
          children: [
            for (final r in _Recency.values)
              RadioListTile<_Recency>(
                title: Text(r.label),
                dense: true,
                value: r,
              ),
          ],
        ),
      ),
    );
  }

  Widget _navigationButtons({
    required VoidCallback onNext,
    String? skipLabel,
    VoidCallback? onSkip,
    bool showSkip = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : onNext,
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
        ),
        if (showSkip && (skipLabel != null || onSkip != null)) ...[
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _busy ? null : (onSkip ?? onNext),
            child: Text(skipLabel ?? 'Skip this step'),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow(
    ThemeData theme, {
    required PageState state,
    required String label,
    required String pages,
    required int count,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StateBadge(state: state),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (pages.isNotEmpty)
                  Text(
                    pages,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('$count', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

/// One bar per wizard step; the steps reached so far are filled.
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: i <= current
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
