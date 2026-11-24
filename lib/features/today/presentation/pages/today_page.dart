import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/backup/presentation/providers/backup_providers.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';
import 'package:personaltskmng/features/today/presentation/widgets/day_log_list.dart';
import 'package:personaltskmng/features/today/presentation/widgets/log_card.dart';
import 'package:personaltskmng/features/today/presentation/widgets/plan_card.dart';
import 'package:personaltskmng/features/today/presentation/widgets/reading_draft_card.dart';
import 'package:personaltskmng/features/today/presentation/widgets/worklist_cards.dart';

/// The Today tab, built around what you actually do: see what needs a review and
/// tap it done, memorise the next piece, or type what you did when it is
/// something else; then see what was logged. With an AI set up, ask it for a
/// plan. The calendar button logs for another day (a back-dated log), and says
/// so for as long as it is chosen. When the app comes back on a new calendar
/// day, the statuses and the notes are worked out again.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // The automatic Drive backup runs when the app starts ...
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _autoBackup();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(memoProvider.notifier).refresh();
      // A new calendar day closes the one before: the "I remembered" taps of it
      // are judged now, whatever Today is showing.
      ref.read(notesViewModelProvider.notifier).refresh();
      // ... and when it comes back to the front.
      _autoBackup();
    }
  }

  /// Writes the Drive backup when one is due (connected, a frequency other than
  /// "manual", the last backup old enough). Silent: it never shows anything and
  /// never throws; a failed try stays due for the next start or resume. Builds
  /// without the Drive wiring (widget tests) simply skip it.
  void _autoBackup() {
    try {
      unawaited(
        ref
            .read(driveBackupServiceProvider)
            .backupIfDue(
              frequency: ref.read(settingsViewModelProvider).backupFrequency,
              memo: ref.read(memoControllerProvider),
              settingsRepo: ref.read(settingsRepositoryProvider),
              notes: ref.read(notesControllerProvider),
            )
            .then((wrote) {
              // The backup noted its time in the stored settings: read them
              // again, so the settings screen shows it and a later change of
              // another setting does not write the old time back.
              if (wrote && mounted) ref.invalidate(settingsViewModelProvider);
            }),
      );
    } catch (_) {}
  }

  Future<void> _pickDay(Day today) async {
    final current = ref.read(logDayProvider) ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.toDateTime(),
      firstDate: DateTime.utc(2020, 1, 1),
      lastDate: today.toDateTime(),
    );
    if (picked == null) return;
    final day = Day.fromDate(picked.year, picked.month, picked.day);
    ref.read(logDayProvider.notifier).choose(day == today ? null : day);
  }

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    final chosen = ref.watch(logDayProvider);
    final problem = ref.read(memoControllerProvider).loadProblem;
    return Scaffold(
      appBar: AppBar(
        title: Text(text.todayTitle),
        actions: [
          IconButton(
            tooltip: text.pickDay,
            icon: Icon(
              chosen == null ? Icons.event_rounded : Icons.event_available_rounded,
            ),
            onPressed: () => _pickDay(memo.today),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (problem != null) ...[
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(text.loadProblem),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (chosen != null) ...[
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.history_rounded),
                    title: Text(text.loggingFor(chosen.toString())),
                    trailing: TextButton(
                      onPressed: () =>
                          ref.read(logDayProvider.notifier).choose(null),
                      child: Text(text.backToToday),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              const GettingStartedCard(),
              const ReadingDraftCard(),
              const AttentionCard(),
              const SizedBox(height: AppSpacing.md),
              const NextToMemoriseCard(),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: ExpansionTile(
                  title: Text(text.typeIt, style: theme.textTheme.titleMedium),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: const [LogCard()],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const DayLogList(),
              const SizedBox(height: AppSpacing.md),
              const PlanCard(),
            ],
          ),
        ),
      ),
    );
  }
}
