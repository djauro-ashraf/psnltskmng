import 'dart:convert';

import 'package:personaltskmng/memo/models/reading_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the reading evidence (`reading.json`) lives. Not precious: a file that
/// cannot be read is simply replaced by an empty log. Saving can throw.
abstract interface class ReadingStore {
  Future<ReadingLog> load();

  Future<void> save(ReadingLog log);
}

/// In memory (tests, previews).
final class InMemoryReadingStore implements ReadingStore {
  InMemoryReadingStore([this.text]);

  String? text;
  bool failOnSave = false;
  int saves = 0;

  @override
  Future<ReadingLog> load() async {
    final stored = text;
    if (stored == null) return const ReadingLog();
    try {
      return ReadingLog.fromJson(jsonDecode(stored));
    } catch (_) {
      return const ReadingLog();
    }
  }

  @override
  Future<void> save(ReadingLog log) async {
    if (failOnSave) throw StateError('reading.json could not be saved');
    text = jsonEncode(log.toJson());
    saves++;
  }
}

/// On [SharedPreferencesWithCache], for the web.
final class PreferencesReadingStore implements ReadingStore {
  PreferencesReadingStore(this._prefs);

  static const String key = 'reading_v1';

  final SharedPreferencesWithCache _prefs;

  @override
  Future<ReadingLog> load() async {
    final text = _prefs.getString(key);
    if (text == null) return const ReadingLog();
    try {
      return ReadingLog.fromJson(jsonDecode(text));
    } catch (_) {
      return const ReadingLog();
    }
  }

  @override
  Future<void> save(ReadingLog log) =>
      _prefs.setString(key, jsonEncode(log.toJson()));
}
