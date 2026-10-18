import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/app/app.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

import 'support/fake_settings_repository.dart';

/// Builds a [PlanningController] backed by empty in-memory stores and loads
/// it (returns [PlanningLoadStartedFresh] because no data exists yet).
Future<PlanningController> _freshController() async {
  final ctrl = PlanningController(
    store: InMemoryAppStateStore(),
    dayRecords: InMemoryDayRecordStore(),
  );
  await ctrl.load();
  return ctrl;
}

Widget _app(
  FakeSettingsRepository repository,
  PlanningController controller,
) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repository),
      planningControllerProvider.overrideWithValue(controller),
    ],
    child: const PersonalTskMngApp(),
  );
}

void main() {
  testWidgets('opens on Today and can navigate to Settings', (tester) async {
    final ctrl = await _freshController();
    await tester.pumpWidget(_app(FakeSettingsRepository(), ctrl));
    await tester.pumpAndSettle();

    expect(find.text('Set up your Q'), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('renders in French when the language is set to fr', (
    tester,
  ) async {
    final ctrl = await _freshController();
    await tester.pumpWidget(
      _app(
        FakeSettingsRepository(initial: const AppSettings(localeCode: 'fr')),
        ctrl,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
