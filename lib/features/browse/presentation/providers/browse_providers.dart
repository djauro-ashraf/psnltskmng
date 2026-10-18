import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/planning_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/today_view_model.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';

/// What the browse screens read besides the fixed tables: the states of the
/// Q and the open-note counts (see [BrowseData]). Read-only: nothing here
/// changes the Q.
///
/// Like the Overview, it takes the latest Q from the Today session (so it is
/// read again after every log) and falls back to the stored Q. While the
/// stored data could not be loaded there is no Q: every page then reads as ND.
/// Tests may override this provider with a [BrowseData] they built.
final browseDataProvider = Provider<BrowseData>((ref) {
  final load = ref.watch(planningViewModelProvider);
  final sessionQ = ref.watch(
    todayViewModelProvider.select((state) => state.session?.currentQ),
  );
  final sessionDay = ref.watch(
    todayViewModelProvider.select((state) => state.session?.day),
  );
  ref.watch(settingsRevisionProvider);
  final index = ref.watch(notesViewModelProvider.select((state) => state.index));
  final controller = ref.read(planningControllerProvider);

  final Q? q = load is PlanningLoadFailed
      ? null
      : (sessionQ ?? controller.state.q);
  final day = sessionDay ?? Day.fromDateTime(ref.read(todayClockProvider)());
  return BrowseData.build(
    q: q,
    day: day,
    lMonthDays: controller.settings.constraints.lMonthDays,
    notes: index,
  );
});
