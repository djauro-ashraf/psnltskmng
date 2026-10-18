import 'dart:convert';
import 'dart:io';

import 'package:personaltskmng/planning/day/day_record.dart';

/// One small JSON file per (Q, day) in [directory]. Saving rewrites just that
/// day's file, so storage cost does not grow with history. Pass an app
/// documents directory from the composition root.
final class JsonDirDayRecordStore implements DayRecordStore {
  JsonDirDayRecordStore(this.directory);

  final Directory directory;

  static String _safe(String s) => s.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  File _fileForKey(String qId, String day) => File(
    '${directory.path}${Platform.pathSeparator}'
    '${_safe(qId)}_$day.json',
  );

  File _fileFor(DayRecord record) => _fileForKey(record.qId, record.day);

  @override
  Future<void> save(DayRecord record) async {
    await directory.create(recursive: true);
    await _fileFor(record).writeAsString(jsonEncode(record.json), flush: true);
  }

  @override
  Future<Map<String, Object?>?> read(String qId, String day) async {
    final file = _fileForKey(qId, day);
    if (!await file.exists()) return null;
    // A record that cannot be read is not "no record": it throws, so the
    // caller (the notes' day-end check) waits instead of judging on nothing.
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw FormatException('the record of $day is not a JSON object');
    }
    return Map<String, Object?>.from(decoded);
  }

  @override
  Future<List<Map<String, Object?>>> readAll() async {
    if (!await directory.exists()) return const [];
    final files = <File>[];
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.json')) files.add(entity);
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    final out = <Map<String, Object?>>[];
    for (final file in files) {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, dynamic>) out.add(decoded);
    }
    return out;
  }
}
