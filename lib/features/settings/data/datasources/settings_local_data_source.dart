import 'dart:convert';

import 'package:personaltskmng/core/errors/failure.dart';
import 'package:personaltskmng/features/settings/data/models/settings_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads and writes the settings JSON in shared_preferences (in-memory cache
/// backed, so reads are synchronous).
class SettingsLocalDataSource {
  SettingsLocalDataSource(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const String _key = 'app_settings';

  /// Null when nothing is stored yet or the stored record cannot be decoded.
  SettingsModel? read() {
    final String? raw;
    try {
      raw = _prefs.getString(_key);
    } catch (e) {
      throw StorageFailure(e);
    }
    if (raw == null) return null;
    try {
      return SettingsModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(SettingsModel model) async {
    try {
      await _prefs.setString(_key, jsonEncode(model.toJson()));
    } catch (e) {
      throw StorageFailure(e);
    }
  }
}
