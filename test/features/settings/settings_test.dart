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

    test('the text runs right to left unless set otherwise', () {
      expect(
        const AppSettings().readingDirection,
        ReadingDirection.rightToLeft,
      );
    });

    test('copyWith changes only the reading direction', () {
      const settings = AppSettings(localeCode: 'fr');
      final next = settings.copyWith(
        readingDirection: ReadingDirection.leftToRight,
      );
      expect(next.readingDirection, ReadingDirection.leftToRight);
      expect(next.localeCode, 'fr');
      expect(next, isNot(settings));
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

    test('the reading direction round-trips through json', () {
      const original = AppSettings(
        readingDirection: ReadingDirection.leftToRight,
      );
      final json = SettingsModel.fromEntity(original).toJson();
      expect(json['readingDirection'], 'leftToRight');
      expect(SettingsModel.fromJson(json).toEntity(), original);
    });

    test('an unknown or missing reading direction reads right to left', () {
      final unknown = SettingsModel.fromJson({'readingDirection': 'sideways'});
      expect(unknown.toEntity().readingDirection, ReadingDirection.rightToLeft);
      // Settings stored (or backed up) before the setting existed.
      final old = SettingsModel.fromJson({'themeMode': 'dark'});
      expect(old.toEntity().readingDirection, ReadingDirection.rightToLeft);
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

    test('applies a reading direction and persists it', () async {
      final repository = FakeSettingsRepository();
      final container = containerWith(repository);

      final failure = await container
          .read(settingsViewModelProvider.notifier)
          .setReadingDirection(ReadingDirection.leftToRight);

      expect(failure, isNull);
      expect(
        container.read(settingsViewModelProvider).readingDirection,
        ReadingDirection.leftToRight,
      );
      expect(repository.stored.readingDirection, ReadingDirection.leftToRight);
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
