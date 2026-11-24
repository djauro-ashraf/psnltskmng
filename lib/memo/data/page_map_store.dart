import 'dart:convert';

import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the page map read from the layout of a print, so it is there at once
/// (and offline) the next time. Not part of the backup: it is derived data.
abstract interface class PageMapStore {
  PageMap? load(MushafEdition edition);

  Future<void> save(MushafEdition edition, PageMap map);
}

/// In memory only (the default, and tests).
final class MemoryPageMapStore implements PageMapStore {
  final Map<MushafEdition, PageMap> _maps = {};

  @override
  PageMap? load(MushafEdition edition) => _maps[edition];

  @override
  Future<void> save(MushafEdition edition, PageMap map) async =>
      _maps[edition] = map;
}

/// In the app preferences, one entry per print.
final class SharedPageMapStore implements PageMapStore {
  SharedPageMapStore(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static String _key(MushafEdition edition) => 'memo.pagemap.${edition.name}';

  @override
  PageMap? load(MushafEdition edition) {
    final text = _prefs.getString(_key(edition));
    if (text == null) return null;
    try {
      return PageMap.fromJson(jsonDecode(text));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(MushafEdition edition, PageMap map) =>
      _prefs.setString(_key(edition), jsonEncode(map.toJson()));
}
