import 'package:personaltskmng/core/errors/failure.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/domain/repositories/settings_repository.dart';

/// In-memory [SettingsRepository] for tests. Shows the point of the LEGO
/// layout: any storage can be swapped in through one provider override.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({
    AppSettings initial = const AppSettings(),
    this.failOnSave = false,
  }) : stored = initial;

  AppSettings stored;
  final bool failOnSave;

  @override
  AppSettings load() => stored;

  @override
  Future<void> save(AppSettings settings) async {
    if (failOnSave) throw const StorageFailure();
    stored = settings;
  }
}
