import 'package:personaltskmng/memo/data/memo_codec.dart';
import 'package:personaltskmng/memo/models/memo_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The result of loading `memo.json`. A file that cannot be used is moved aside
/// (never overwritten) and the app starts empty with the reason in [problem].
/// A missing file is not a problem: [found] is false.
final class MemoLoadResult {
  const MemoLoadResult(
    this.data, {
    this.found = true,
    this.problem,
    this.quarantinedAs,
  });

  final MemoData data;
  final bool found;
  final String? problem;
  final String? quarantinedAs;
}

/// Where `memo.json` lives. Saving can throw; the caller tells the user. Pure
/// Dart (no dart:io here, see `FileMemoStore`).
abstract interface class MemoStore {
  Future<MemoLoadResult> load();

  Future<void> save(MemoData data);
}

/// Keeps the file as text in memory (tests, previews). Same codec as the real
/// stores.
final class InMemoryMemoStore implements MemoStore {
  InMemoryMemoStore([this.text]);

  /// The content of `memo.json`, or null when there is none.
  String? text;

  /// Tests set this to make [save] throw.
  bool failOnSave = false;

  int saves = 0;

  @override
  Future<MemoLoadResult> load() async {
    final stored = text;
    if (stored == null) return const MemoLoadResult(MemoData(), found: false);
    try {
      return MemoLoadResult(MemoCodec.fromText(stored));
    } on FormatException catch (e) {
      text = null;
      return MemoLoadResult(const MemoData(), problem: e.message);
    }
  }

  @override
  Future<void> save(MemoData data) async {
    if (failOnSave) throw StateError('memo.json could not be saved');
    text = MemoCodec.toText(data);
    saves++;
  }
}

/// [MemoStore] on [SharedPreferencesWithCache], for the web.
final class PreferencesMemoStore implements MemoStore {
  PreferencesMemoStore(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const String key = 'memo_v1';

  final SharedPreferencesWithCache _prefs;
  final DateTime Function() _clock;

  @override
  Future<MemoLoadResult> load() async {
    final text = _prefs.getString(key);
    if (text == null) return const MemoLoadResult(MemoData(), found: false);
    try {
      return MemoLoadResult(MemoCodec.fromText(text));
    } on FormatException catch (e) {
      final badKey = '$key.bad_${_clock().millisecondsSinceEpoch}';
      await _prefs.setString(badKey, text);
      await _prefs.remove(key);
      return MemoLoadResult(
        const MemoData(),
        problem: e.message,
        quarantinedAs: badKey,
      );
    }
  }

  @override
  Future<void> save(MemoData data) => _prefs.setString(key, MemoCodec.toText(data));
}
