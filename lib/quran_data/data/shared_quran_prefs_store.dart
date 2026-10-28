import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the Quran choices in the app's preferences.
class SharedQuranPrefsStore implements QuranPrefsStore {
  SharedQuranPrefsStore(this._prefs);

  final SharedPreferencesWithCache _prefs;

  @override
  String? get(String key) => _prefs.getString(key);

  @override
  Future<void> set(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);
}
