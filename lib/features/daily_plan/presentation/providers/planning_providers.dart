import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';

/// The planning controller (storage + engine + service). Throws until it is
/// overridden in the composition root (app/dependencies.dart); tests override
/// it with a controller on an in-memory store.
final planningControllerProvider = Provider<PlanningController>(
  (ref) => throw UnimplementedError('override in app/dependencies.dart'),
);

/// The clock the Today screen reads. Tests override it.
final todayClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Bumped every time the planning settings are saved, so screens that show
/// values derived from them (the Overview's L days) read them again.
class SettingsRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final settingsRevisionProvider = NotifierProvider<SettingsRevision, int>(
  SettingsRevision.new,
);
