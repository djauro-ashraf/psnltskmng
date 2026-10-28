import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the chosen edition in the app's preferences.
class SharedMushafEditionStore implements MushafEditionStore {
  SharedMushafEditionStore(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const String key = 'mushaf.edition';

  @override
  MushafEdition load() =>
      MushafEdition.values.asNameMap()[_prefs.getString(key)] ??
      MushafEdition.standard;

  @override
  Future<void> save(MushafEdition edition) =>
      _prefs.setString(key, edition.name);
}
