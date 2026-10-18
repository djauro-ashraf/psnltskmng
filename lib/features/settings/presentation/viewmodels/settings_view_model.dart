import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/errors/failure.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';

/// Synchronous state (settings are preloaded at startup): no loading flash and
/// no AsyncValue handling in widgets. Changes apply instantly and roll back if
/// saving fails.
class SettingsViewModel extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(settingsRepositoryProvider).load();

  Future<Failure?> setThemeMode(AppThemeMode mode) {
    return _save(state.copyWith(themeMode: mode));
  }

  /// [localeCode] null = follow the system language.
  Future<Failure?> setLocaleCode(String? localeCode) {
    return _save(state.copyWith(localeCode: localeCode));
  }

  Future<Failure?> setAiEnabled(bool enabled) =>
      _save(state.copyWith(aiEnabled: enabled));

  Future<Failure?> setAiProvider(String providerId) =>
      _save(state.copyWith(aiProvider: providerId));

  /// An empty [model] removes the entry (the provider's default is used).
  Future<Failure?> setAiModel(String providerId, String model) {
    final models = {...state.aiModels};
    if (model.trim().isEmpty) {
      models.remove(providerId);
    } else {
      models[providerId] = model.trim();
    }
    return _save(state.copyWith(aiModels: models));
  }

  Future<Failure?> setBackupFrequency(String frequency) =>
      _save(state.copyWith(backupFrequency: frequency));

  Future<Failure?> setGoogleDriveConnected(
    bool connected, {
    String? email,
  }) => _save(
    state.copyWith(
      googleDriveConnected: connected,
      googleDriveEmail: email,
    ),
  );

  Future<Failure?> updateLastBackupTime(DateTime time) =>
      _save(state.copyWith(lastBackupTime: time.toIso8601String()));

  Future<Failure?> _save(AppSettings next) async {
    if (next == state) return null;
    final previous = state;
    state = next;
    try {
      await ref.read(settingsRepositoryProvider).save(next);
      return null;
    } on Failure catch (failure) {
      if (ref.mounted) state = previous;
      return failure;
    } catch (error) {
      if (ref.mounted) state = previous;
      return StorageFailure(error);
    }
  }
}

final settingsViewModelProvider =
    NotifierProvider<SettingsViewModel, AppSettings>(SettingsViewModel.new);
