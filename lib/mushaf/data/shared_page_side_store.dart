import 'package:personaltskmng/mushaf/controller/page_side.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the page side in the app's preferences.
class SharedPageSideStore implements PageSideStore {
  SharedPageSideStore(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const String key = 'mushaf.pageSide';

  @override
  PageSide load() =>
      PageSide.values.asNameMap()[_prefs.getString(key)] ?? PageSide.info;

  @override
  Future<void> save(PageSide side) => _prefs.setString(key, side.name);
}
