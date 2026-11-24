import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/app/app.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/memo/presentation/providers/reading_providers.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/features/today/presentation/pages/today_page.dart';
import 'package:personaltskmng/memo/controller/memo_controller.dart';
import 'package:personaltskmng/memo/controller/reading_controller.dart';
import 'package:personaltskmng/memo/data/memo_store.dart';
import 'package:personaltskmng/memo/data/reading_store.dart';

import 'support/fake_settings_repository.dart';

/// A [MemoController] on an empty in-memory store, loaded (a first run).
Future<MemoController> _freshController() async {
  final controller = MemoController(store: InMemoryMemoStore());
  await controller.load();
  return controller;
}

Widget _app(FakeSettingsRepository repository, MemoController memo) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(repository),
      memoControllerProvider.overrideWithValue(memo),
      readingControllerProvider.overrideWithValue(
        ReadingController(store: InMemoryReadingStore()),
      ),
    ],
    child: const PersonalTskMngApp(),
  );
}

void main() {
  testWidgets('opens on Today and can navigate to Settings', (tester) async {
    final memo = await _freshController();
    await tester.pumpWidget(_app(FakeSettingsRepository(), memo));
    await tester.pumpAndSettle();

    expect(find.byType(TodayPage), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('renders in French when the language is set to fr', (
    tester,
  ) async {
    final memo = await _freshController();
    await tester.pumpWidget(
      _app(
        FakeSettingsRepository(initial: const AppSettings(localeCode: 'fr')),
        memo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paramètres'), findsOneWidget);
    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
