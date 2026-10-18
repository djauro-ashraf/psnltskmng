import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

import '../planning/support.dart';

/// A planning controller that is LOADED (the first-run setup is done) on
/// in-memory stores: the example Q (604 pages, main D range 282-322) created on
/// day 4, so that day 5 needs nothing but today's session. Day records go to
/// [records], so a notes controller can read the same log.
Future<PlanningController> loadedPlanning({
  required InMemoryDayRecordStore records,
  required DateTime Function() clock,
}) async {
  final store = InMemoryAppStateStore();
  await store.saveState(
    StoredState.ofQ(
      testEngine.createQ(
        id: 'q',
        totalPages: 604,
        initialMainD: const PageRange(282, 322),
        today: const Day(4),
      ),
    ),
  );
  await store.saveSettings(const PlanningSettings(baseBudgetMinutes: 1200));
  final controller = PlanningController(
    store: store,
    dayRecords: records,
    clock: clock,
  );
  await controller.load();
  return controller;
}
