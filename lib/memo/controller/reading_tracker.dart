import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/span.dart';

/// Receives time spent on a page: [seconds] on [page] (whose ayahs are [span])
/// on [day], and [visits] more openings of it.
typedef DwellSink =
    void Function(int page, Span span, Day day, int seconds, int visits);

/// Measures how long each page is in front of the reader. Pure Dart: the reader
/// tells it what happens (a page is shown, the screen is touched, the app goes
/// to the background) and it reports seconds, never more than the user was
/// plausibly there.
///
/// A visit counts from the moment the page is shown until [idleCap] after the
/// last touch, or until the app is paused or the page changes. The cap is
/// generous because reciting while looking at a page does not touch the screen;
/// it only exists so a phone left open on a page does not read all night.
final class ReadingTracker {
  ReadingTracker({
    required this.sink,
    required this.spanOf,
    required this.idleCap,
    this.enabled = true,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final DwellSink sink;

  /// The ayahs of a page in the print being read.
  final Span Function(int page) spanOf;
  final Duration idleCap;

  /// False: nothing is measured.
  final bool enabled;
  final DateTime Function() _clock;

  int? _page;
  DateTime? _segmentStart;
  DateTime? _lastActive;
  bool _paused = false;

  /// The page the reader is showing now.
  int? get page => _page;

  /// The user is now looking at [page].
  void pageShown(int page) {
    if (!enabled) return;
    final now = _clock();
    if (_page == page && !_paused) {
      interaction();
      return;
    }
    _close(now);
    _page = page;
    _paused = false;
    _segmentStart = now;
    _lastActive = now;
    sink(page, spanOf(page), Day.fromDateTime(now), 0, 1);
  }

  /// The screen was touched or scrolled.
  void interaction() {
    if (!enabled || _page == null || _paused) return;
    final now = _clock();
    final active = _lastActive;
    if (active != null && now.difference(active) > idleCap) {
      _close(now);
    }
    _lastActive = now;
  }

  /// The app went to the background, the screen turned off, or the reader was
  /// covered.
  void pause() {
    if (!enabled || _page == null || _paused) return;
    _close(_clock());
    _paused = true;
  }

  /// The reader is back in front.
  void resume() {
    if (!enabled || _page == null || !_paused) return;
    final now = _clock();
    _paused = false;
    _segmentStart = now;
    _lastActive = now;
  }

  /// Reports the time so far and keeps counting (called now and then, so little
  /// is lost if the app is killed).
  void flush() {
    if (!enabled || _page == null || _paused) return;
    _close(_clock());
  }

  /// The reader was closed.
  void leave() {
    if (!enabled) return;
    if (_page != null && !_paused) _close(_clock());
    _page = null;
    _paused = true;
  }

  /// Reports the segment up to the idle cap and starts the next one at [now].
  void _close(DateTime now) {
    final page = _page;
    final start = _segmentStart;
    final active = _lastActive;
    if (page == null || start == null || active == null || _paused) return;
    final limit = active.add(idleCap);
    final end = now.isBefore(limit) ? now : limit;
    final seconds = end.difference(start).inSeconds;
    if (seconds > 0) {
      sink(page, spanOf(page), Day.fromDateTime(start), seconds, 0);
    }
    _segmentStart = now;
  }
}
