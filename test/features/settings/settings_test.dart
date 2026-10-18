import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/core/errors/failure.dart';
import 'package:personaltskmng/features/settings/data/models/settings_model.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';

import '../../support/fake_settings_repository.dart';

void main() {
  group('AppSettings', () {
    test('copyWith keeps the language when it is omitted', () {
      const settings = AppSettings(localeCode: 'fr');
      final next = settings.copyWith(themeMode: AppThemeMode.dark);
      expect(next.localeCode, 'fr');
      expect(next.themeMode, AppThemeMode.dark);
    });

    test('copyWith can clear the language back to system', () {
      const settings = AppSettings(localeCode: 'fr');
      expect(settings.copyWith(localeCode: null).localeCode, isNull);
    });

    test('has value equality', () {
      expect(
        const AppSettings(themeMode: AppThemeMode.light, localeCode: 'en'),
        const AppSettings(themeMode: AppThemeMode.light, localeCode: 'en'),
      );
    });
  });

  group('SettingsModel', () {
    test('round-trips through json', () {
      const original = AppSettings(
        themeMode: AppThemeMode.dark,
        localeCode: 'fr',
      );
      final json = SettingsModel.fromEntity(original).toJson();
      expect(SettingsModel.fromJson(json).toEntity(), original);
    });

    test('unknown theme mode falls back to system', () {
      final model = SettingsModel.fromJson({'themeMode': 'neon'});
      expect(model.toEntity().themeMode, AppThemeMode.system);
    });

    test('missing fields fall back to defaults', () {
      expect(SettingsModel.fromJson({}).toEntity(), const AppSettings());
    });
  });

  group('SettingsViewModel', () {
    ProviderContainer containerWith(FakeSettingsRepository repository) {
      final container = ProviderContainer(
        overrides: [settingsRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('starts from the stored settings', () {
      final container = containerWith(
        FakeSettingsRepository(
          initial: const AppSettings(themeMode: AppThemeMode.dark),
        ),
      );
      expect(
        container.read(settingsViewModelProvider).themeMode,
        AppThemeMode.dark,
      );
    });

    test('applies a change and persists it', () async {
      final repository = FakeSettingsRepository();
      final container = containerWith(repository);

      final failure = await container
          .read(settingsViewModelProvider.notifier)
          .setLocaleCode('fr');

      expect(failure, isNull);
      expect(container.read(settingsViewModelProvider).localeCode, 'fr');
      expect(repository.stored.localeCode, 'fr');
    });

    test('rolls back and reports a failure when saving fails', () async {
      final container = containerWith(FakeSettingsRepository(failOnSave: true));

      final failure = await container
          .read(settingsViewModelProvider.notifier)
          .setThemeMode(AppThemeMode.dark);

      expect(failure, isA<StorageFailure>());
      expect(
        container.read(settingsViewModelProvider).themeMode,
        AppThemeMode.system,
      );
    });
  });
}
