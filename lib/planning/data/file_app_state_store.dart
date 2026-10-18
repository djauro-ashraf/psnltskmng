import 'dart:io';

import 'package:personaltskmng/planning/data/app_state_codec.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/stored_state.dart';

/// [AppStateStore] on files in [directory] (the app documents directory,
/// given by the composition root): `state.json` and `settings.json`. The only
/// store that imports dart:io.
///
/// - **Atomic writes.** Each save writes `<name>.tmp`, flushes it, then
///   renames it over the target. A crash or an error before the rename leaves
///   the old target untouched; a leftover `.tmp` is never read by a load.
///   Saves are queued so two writes never overlap.
/// - **Bad file.** A file that cannot be read or decoded (or whose Q fails its
///   own check) is renamed to `<name>.bad-<timestamp>` and the load returns a
///   failure with the reason. Nothing is written over it afterwards by this
///   class; the controller refuses to save until the user starts fresh.
final class FileAppStateStore implements AppStateStore {
  FileAppStateStore(this.directory, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const String stateFileName = 'state.json';
  static const String settingsFileName = 'settings.json';

  final Directory directory;
  final DateTime Function() _clock;

  Future<void> _tail = Future<void>.value();

  /// The folder for the day records (`days`), in the same directory.
  Directory get daysDirectory => Directory(_path('days'));

  String _path(String name) => '${directory.path}${Platform.pathSeparator}$name';

  File _file(String name) => File(_path(name));

  @override
  Future<StateLoadResult> loadState() async {
    final read = await _read(stateFileName);
    switch (read) {
      case _Missing():
        return const StateNotFound();
      case _Unreadable(:final reason):
        final moved = await _quarantine(stateFileName);
        return StateLoadFailed(
          '$stateFileName: $reason${moved.note}',
          quarantinedAs: moved.name,
        );
      case _Text(:final text):
        try {
          return StateLoaded(AppStateCodec.stateFromText(text));
        } on FormatException catch (e) {
          final moved = await _quarantine(stateFileName);
          return StateLoadFailed(
            '$stateFileName: ${e.message}${moved.note}',
            quarantinedAs: moved.name,
          );
        }
    }
  }

  @override
  Future<void> saveState(StoredState state) =>
      _writeAtomic(stateFileName, AppStateCodec.stateToText(state));

  @override
  Future<SettingsLoadResult> loadSettings() async {
    final read = await _read(settingsFileName);
    switch (read) {
      case _Missing():
        return const SettingsNotFound();
      case _Unreadable(:final reason):
        final moved = await _quarantine(settingsFileName);
        return SettingsLoadFailed(
          '$settingsFileName: $reason${moved.note}',
          quarantinedAs: moved.name,
        );
      case _Text(:final text):
        try {
          final decoded = AppStateCodec.settingsFromText(text);
          return SettingsLoaded(decoded.settings, decoded.problems);
        } on FormatException catch (e) {
          final moved = await _quarantine(settingsFileName);
          return SettingsLoadFailed(
            '$settingsFileName: ${e.message}${moved.note}',
            quarantinedAs: moved.name,
          );
        }
    }
  }

  @override
  Future<void> saveSettings(PlanningSettings settings) =>
      _writeAtomic(settingsFileName, AppStateCodec.settingsToText(settings));

  Future<_ReadResult> _read(String name) async {
    final file = _file(name);
    try {
      if (!await file.exists()) return const _Missing();
      return _Text(await file.readAsString());
    } catch (e) {
      return _Unreadable('cannot be read ($e)');
    }
  }

  /// Moves the file aside as `<name>.bad-<timestamp>`.
  Future<({String? name, String note})> _quarantine(String name) async {
    final badName = '$name.bad-${_clock().millisecondsSinceEpoch}';
    try {
      await _file(name).rename(_path(badName));
      return (name: badName, note: ' (moved to $badName)');
    } catch (e) {
      return (name: null, note: ' (could not be moved aside: $e)');
    }
  }

  /// Write `<name>.tmp`, flush, rename over `<name>`. Serialized.
  Future<void> _writeAtomic(String name, String text) {
    final job = _tail.then((_) async {
      await directory.create(recursive: true);
      final tmp = _file('$name.tmp');
      RandomAccessFile? out;
      try {
        out = await tmp.open(mode: FileMode.write);
        await out.writeString(text);
        await out.flush();
        await out.close();
        out = null;
        await tmp.rename(_path(name));
      } catch (_) {
        try {
          await out?.close();
        } catch (_) {}
        try {
          if (await tmp.exists()) await tmp.delete();
        } catch (_) {}
        rethrow;
      }
    });
    _tail = job.then<void>((_) {}, onError: (Object _) {});
    return job;
  }
}

sealed class _ReadResult {
  const _ReadResult();
}

final class _Missing extends _ReadResult {
  const _Missing();
}

final class _Unreadable extends _ReadResult {
  const _Unreadable(this.reason);

  final String reason;
}

final class _Text extends _ReadResult {
  const _Text(this.text);

  final String text;
}
