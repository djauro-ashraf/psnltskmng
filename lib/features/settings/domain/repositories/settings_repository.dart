import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';

abstract interface class SettingsRepository {
  /// Synchronous on purpose: settings are cached in memory at startup, so the
  /// very first frame already has the right theme and language.
  AppSettings load();

  Future<void> save(AppSettings settings);
}
