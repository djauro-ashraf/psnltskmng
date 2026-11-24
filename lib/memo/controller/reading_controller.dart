import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/data/reading_store.dart';
import 'package:personaltskmng/memo/models/reading_log.dart';
import 'package:personaltskmng/memo/models/span.dart';

/// Holds the reading evidence and saves it. Recording is in memory only (it
/// happens every few seconds while reading); [persist] writes when there is
/// something new, and the reader calls it now and then and when it closes.
/// Pure Dart; the Riverpod providers only expose it.
final class ReadingController {
  ReadingController({required this.store});

  final ReadingStore store;

  ReadingLog _log = const ReadingLog();
  bool _dirty = false;
  Future<void> _tail = Future<void>.value();

  ReadingLog get log => _log;

  /// Reads the file and drops evidence older than [keepDays].
  Future<void> load(
    Day today, {
    int keepDays = ReadingLog.defaultKeepDays,
  }) async {
    try {
      final loaded = await store.load();
      _log = loaded.pruned(today.epochDay, keepDays: keepDays);
      _dirty = _log.dwells.length != loaded.dwells.length;
    } catch (_) {
      _log = const ReadingLog();
    }
  }

  /// Adds time on a page (memory only; see [persist]).
  void record({
    required Day day,
    required int page,
    required Span span,
    required int seconds,
    required int visits,
  }) {
    if (seconds <= 0 && visits <= 0) return;
    _log = _log.add(
      day: day.epochDay,
      page: page,
      span: span,
      seconds: seconds,
      visits: visits,
    );
    _dirty = true;
  }

  /// Writes what is new. Returns whether something was written. A failed save
  /// keeps the data and tries again next time.
  Future<bool> persist() {
    if (!_dirty) return Future<bool>.value(false);
    _dirty = false;
    final snapshot = _log;
    final job = _tail.then((_) async {
      try {
        await store.save(snapshot);
        return true;
      } catch (_) {
        _dirty = true;
        return false;
      }
    });
    _tail = job.then<void>((_) {});
    return job;
  }

  /// Marks pages as done with (confirmed or dismissed).
  Future<void> dismiss(Day day, Iterable<int> firsts) {
    _log = _log.dismiss(day.epochDay, firsts);
    _dirty = true;
    return persist();
  }

  /// Brings dismissed pages back (an undo of a confirmation).
  Future<void> undismiss(Day day, Iterable<int> firsts) {
    _log = _log.undismiss(day.epochDay, firsts);
    _dirty = true;
    return persist();
  }

  /// Forgets everything.
  Future<void> erase() {
    _log = const ReadingLog();
    _dirty = true;
    return persist();
  }
}
