import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/features/backup/presentation/providers/backup_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/planning_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/today_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/failed_load_view.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/setup_view.dart';
import 'package:personaltskmng/features/daily_plan/presentation/widgets/today_view.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';

/// The Today tab. By the result of the start-up load it shows: the reason and
/// "Start fresh" (failed), the first-run setup (empty-started) or Today
/// (loaded). When the app comes back on a new calendar day, Today starts a new
/// session.
class DailyPlanPage extends ConsumerStatefulWidget {
  const DailyPlanPage({super.key});

  @override
  ConsumerState<DailyPlanPage> createState() => _DailyPlanPageState();
}

class _DailyPlanPageState extends ConsumerState<DailyPlanPage>
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
      ref.read(todayViewModelProvider.notifier).refreshDay();
      // A new calendar day closes the one before: the "I remembered" taps of
      // it are judged now, whatever Today is showing.
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
              controller: ref.read(planningControllerProvider),
              settingsRepo: ref.read(settingsRepositoryProvider),
              dayRecordsStore: ref.read(dayRecordStoreProvider),
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

  @override
  Widget build(BuildContext context) {
    final load = ref.watch(planningViewModelProvider);
    return switch (load) {
      PlanningLoadFailed(:final reason) => FailedLoadView(reason: reason),
      PlanningEmptyStarted() => const SetupView(),
      PlanningLoaded() => const TodayView(),
    };
  }
}
