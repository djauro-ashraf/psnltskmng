import 'package:personaltskmng/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:personaltskmng/features/settings/data/models/settings_model.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._dataSource);

  final SettingsLocalDataSource _dataSource;

  @override
  AppSettings load() => _dataSource.read()?.toEntity() ?? const AppSettings();

  @override
  Future<void> save(AppSettings settings) {
    return _dataSource.write(SettingsModel.fromEntity(settings));
  }
}
