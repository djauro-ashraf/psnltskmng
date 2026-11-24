import 'dart:typed_data';

import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/memo/models/status_rules.dart';

/// How a stretch of ayahs stands: how many are in each status, the worst
/// status among the learned ones, and how long ago it was touched. Worked out on
/// demand by [MemoView.statusOf], never stored.
final class SpanStatus {
  const SpanStatus({
    required this.ayahs,
    required this.counts,
    required this.worst,
    required this.newestSince,
    required this.oldestSince,
    required this.nextDeadline,
  });

  final int ayahs;
  final List<int> counts;

  /// The weakest status among the learned ayahs: a unit goes by its weakest
  /// part (fading counts at the level it faded from). Not learned when none of
  /// it is learned.
  final MemoStatus worst;

  /// Days since the most recently touched learned ayah was touched, or null.
  final int? newestSince;

  /// Days since the longest untouched learned ayah was touched, or null.
  final int? oldestSince;

  /// The earliest day on which some ayah here falls a step if it gets no review
  /// (the day it is judged, so a review on that day still saves it), or null.
  final Day? nextDeadline;

  /// How many ayahs have [status].
  int count(MemoStatus status) => counts[status.index];

  int get notLearned => count(MemoStatus.notLearned);

  /// Ayahs that are not "not learned".
  int get learned => ayahs - notLearned;

  double get learnedShare => ayahs == 0 ? 0 : learned / ayahs;

  /// Nothing is "not learned".
  bool get isComplete => notLearned == 0;

  /// Ayahs in a fading status (a warning: one review restores them).
  int get fading => count(MemoStatus.fading1) + count(MemoStatus.fading2);

  /// Ayahs that need memorising again.
  int get forgotten => count(MemoStatus.forgotten);
}

/// Every status of every ayah, worked out from the log and the user's rules
/// for one day, by replaying the log in order: each ayah moves through the
/// statuses exactly as the pages used to (memorise starts learning, reviews
/// earn units and climb the levels, days without review make it fade, step down
/// or be forgotten). The log holds facts only, so changing a rule, a partition
/// or the print never needs a migration: the view is simply built again.
///
/// Statuses are judged through yesterday: a review today still saves an ayah
/// whose last day is today. A line that does not fit the status of an ayah (a
/// memorise on one that is learned, a review on one that is not) is kept in the
/// log but changes nothing. Pure Dart.
final class MemoView {
  MemoView._(this.today, this.settings, this._cells);

  /// Builds the view as of [today] from [events] (in any order). Lines dated
  /// after [today] are ignored.
  factory MemoView.build({
    required List<MemoEvent> events,
    required MemoSettings settings,
    required Day today,
    int cells = _Cells.quranSize,
  }) {
    final cells0 = _Cells(settings.rules, cells);
    final ordered = [
      for (final e in events)
        if (!e.day.isAfter(today)) e,
    ]..sort((a, b) {
        final byDay = a.day.epochDay.compareTo(b.day.epochDay);
        return byDay != 0 ? byDay : a.id.compareTo(b.id);
      });
    for (final e in ordered) {
      final d = e.day.epochDay;
      for (var i = e.span.first; i <= e.span.last; i++) {
        cells0.settle(i, d - 1);
        if (e.kind == MemoKind.m) {
          cells0.memorise(i, d);
        } else {
          cells0.review(i, d);
        }
      }
    }
    for (var i = 0; i < cells0.size; i++) {
      cells0.settle(i, today.epochDay - 1);
    }
    return MemoView._(today, settings, cells0);
  }

  /// A view of an empty log (the whole Quran).
  factory MemoView.empty({
    required MemoSettings settings,
    required Day today,
  }) => MemoView.build(events: const [], settings: settings, today: today);

  final Day today;
  final MemoSettings settings;
  final _Cells _cells;

  MemoStatus statusAt(int place) => MemoStatus.values[_cells.status[place]];

  /// Whether the ayah is anything but not learned.
  bool isLearned(int place) => _cells.status[place] != 0;

  /// How firmly the ayah holds, 0 (forgotten) to 4 (consolidated), counting a
  /// fading ayah at the level it faded from; null when not learned.
  int? levelAt(int place) => _cells.level(place);

  /// Days since the ayah was last memorised or reviewed, or null when never.
  int? sinceAt(int place) {
    final touch = _cells.lastTouch(place);
    if (touch == _Cells.none) return null;
    final since = today.epochDay - touch;
    return since < 0 ? 0 : since;
  }

  /// The day the ayah next falls a step if it gets no review, or null (not
  /// learned, forgotten, or already as low as it goes).
  Day? deadlineAt(int place) {
    final day = _cells.deadline(place, today.epochDay);
    return day == null ? null : Day(day);
  }

  /// Reviews the ayah has had in total, memorises likewise.
  int reviewsAt(int place) => _cells.reviews[place];
  int memorisesAt(int place) => _cells.memorises[place];

  /// The counts and ages for [span].
  SpanStatus statusOf(Span span) {
    final counts = List<int>.filled(MemoStatus.values.length, 0);
    var weakest = 99;
    int? newest;
    int? oldest;
    int? deadline;
    for (var i = span.first; i <= span.last; i++) {
      final s = _cells.status[i];
      counts[s]++;
      if (s == 0) continue;
      final level = _cells.level(i)!;
      if (level < weakest) weakest = level;
      final since = sinceAt(i);
      if (since != null) {
        if (newest == null || since < newest) newest = since;
        if (oldest == null || since > oldest) oldest = since;
      }
      final next = _cells.deadline(i, today.epochDay);
      if (next != null && (deadline == null || next < deadline)) deadline = next;
    }
    return SpanStatus(
      ayahs: span.length,
      counts: counts,
      worst: weakest == 99 ? MemoStatus.notLearned : MemoStatus.ofLevel(weakest),
      newestSince: newest,
      oldestSince: oldest,
      nextDeadline: deadline == null ? null : Day(deadline),
    );
  }

  /// The runs inside [span] whose ayahs have a status for which [test] holds.
  List<Span> runsWhere(Span span, bool Function(MemoStatus status) test) {
    final runs = <Span>[];
    int? start;
    for (var i = span.first; i <= span.last; i++) {
      if (test(statusAt(i))) {
        start ??= i;
      } else if (start != null) {
        runs.add(Span(start, i - 1));
        start = null;
      }
    }
    if (start != null) runs.add(Span(start, span.last));
    return runs;
  }

  /// The runs of [span] that Memorise may be logged on (not learned, forgotten).
  List<Span> memoriseEligible(Span span) =>
      runsWhere(span, (s) => s.acceptsMemorise);

  /// The runs of [span] that Review may be logged on (everything learned that
  /// is not forgotten).
  List<Span> reviewEligible(Span span) =>
      runsWhere(span, (s) => s.acceptsReview);
}

/// The per-ayah records the replay works on (one cell per ayah).
final class _Cells {
  _Cells(this.rules, this.size)
    : status = Uint8List(size),
      from = Uint8List(size)..fillRange(0, size, noStatus),
      lastM = Int32List(size)..fillRange(0, size, none),
      lastR = Int32List(size)..fillRange(0, size, none),
      clock = Int32List(size)..fillRange(0, size, none),
      units = Uint8List(size),
      prime = Uint8List(size),
      memorises = Uint16List(size),
      reviews = Uint16List(size);

  /// The Quran has 6,236 ayahs; a preview may use fewer cells.
  static const int quranSize = 6236;

  final int size;
  static const int none = -1000000;
  static const int noStatus = 255;

  static const int _notLearned = 0;
  static const int _learning1 = 1;
  static const int _learning3 = 3;
  static const int _consolidated = 4;
  static const int _fading1 = 5;
  static const int _fading2 = 6;
  static const int _forgotten = 7;

  final StatusRules rules;
  final Uint8List status;

  /// For fading and forgotten ayahs: the status they faded from.
  final Uint8List from;
  final Int32List lastM;
  final Int32List lastR;

  /// The day the ayah last stepped down (the "days without review" clock then
  /// restarts there), or [none].
  final Int32List clock;

  /// Reviews earned toward the next learning level.
  final Uint8List units;

  /// Consolidated at least once, for good.
  final Uint8List prime;
  final Uint16List memorises;
  final Uint16List reviews;

  int lastTouch(int i) => lastM[i] > lastR[i] ? lastM[i] : lastR[i];

  /// The start of the "days without review" clock: the latest of the last
  /// memorise, the last review and the last step down.
  int anchor(int i) {
    final touch = lastTouch(i);
    return clock[i] > touch ? clock[i] : touch;
  }

  int? level(int i) {
    final s = status[i];
    if (s == _notLearned) return null;
    final origin = (s == _fading1 || s == _fading2 || s == _forgotten)
        ? from[i]
        : s;
    if (s == _forgotten) return 0;
    if (origin == noStatus) return 0;
    return origin >= _consolidated ? 4 : origin;
  }

  bool _isPrime(int i) => prime[i] == 1;

  static int _severity(int s) => switch (s) {
    _fading1 => 1,
    _fading2 => 2,
    _forgotten => 3,
    _ => 0,
  };

  /// Judges the ayah for every day through [through]: warnings entered, levels
  /// stepped down, as many times as the elapsed days require.
  void settle(int i, int through) {
    for (var step = 0; step < 8; step++) {
      if (!_stepOnce(i, through)) return;
    }
  }

  bool _stepOnce(int i, int through) {
    final s = status[i];
    if (s == _forgotten || s == _notLearned) return false;
    final origin = (s == _fading1 || s == _fading2) ? from[i] : s;
    if (origin == noStatus) return false;
    final a = anchor(i);
    if (a == none) return false;
    final days = through - a;
    if (days <= 0) return false;
    final prime = _isPrime(i);
    var warning = -1;
    if (origin == _consolidated) {
      if (days >= rules.consolidatedForgotten) {
        warning = _forgotten;
      } else if (days >= rules.consolidatedFade2) {
        warning = _fading2;
      } else if (days >= rules.consolidatedFade1) {
        warning = _fading1;
      }
    } else if (origin >= _learning1 && origin <= _learning3) {
      if (days >= rules.drop(origin, prime: prime)) {
        _stepDown(i, origin, a + rules.drop(origin, prime: prime));
        return true;
      }
      if (days >= rules.fade2(origin, prime: prime)) {
        warning = _fading2;
      } else if (days >= rules.fade1(origin, prime: prime)) {
        warning = _fading1;
      }
    } else {
      return false;
    }
    if (warning < 0 || _severity(warning) <= _severity(s)) return false;
    status[i] = warning;
    from[i] = origin;
    return true;
  }

  /// A learning ayah stepping down one level on [dropDay]. Level 1 falls to not
  /// learned, except a prime one, which is forgotten instead (an ayah that was
  /// consolidated once never goes back to not learned). Progress restarts.
  void _stepDown(int i, int origin, int dropDay) {
    units[i] = 0;
    if (origin == _learning1) {
      if (_isPrime(i)) {
        status[i] = _forgotten;
        from[i] = origin;
      } else {
        status[i] = _notLearned;
        from[i] = noStatus;
        clock[i] = none;
      }
      return;
    }
    status[i] = origin - 1;
    from[i] = noStatus;
    clock[i] = dropDay;
  }

  /// Memorise: allowed on not learned and forgotten; both start learning 1.
  void memorise(int i, int d) {
    final s = status[i];
    if (s != _notLearned && s != _forgotten) return;
    status[i] = _learning1;
    from[i] = noStatus;
    lastM[i] = d;
    units[i] = 0;
    if (memorises[i] < 65000) memorises[i]++;
  }

  /// Review: progress on learning levels, a refresh on consolidated, a full
  /// restore on fading. Not on not learned or forgotten. One per ayah per day.
  void review(int i, int d) {
    final s = status[i];
    if (s == _notLearned || s == _forgotten) return;
    if (lastR[i] == d) return;
    if (s >= _learning1 && s <= _learning3) {
      _progress(i, s, d);
    } else if (s == _fading1 || s == _fading2) {
      status[i] = from[i] == noStatus ? s : from[i];
      from[i] = noStatus;
    }
    lastR[i] = d;
    if (reviews[i] < 65000) reviews[i]++;
  }

  void _progress(int i, int level, int d) {
    final isPrime = _isPrime(i);
    final target = rules.target(level, prime: isPrime);
    final a = anchor(i);
    final gap = a == none ? 1 : d - a;
    final beyond = gap - rules.toleratedGap(level, prime: isPrime);
    final unforgiven = beyond > rules.forgiveness(level);
    var current = units[i];
    if (unforgiven) {
      current = current - rules.penalty(level);
      if (current < 0) current = 0;
      if (current > target) current = target;
    }
    var earned = current + 1;
    if (earned > target) earned = target;
    if (earned >= target) {
      final next = level + 1;
      status[i] = next;
      units[i] = 0;
      if (next == _consolidated) prime[i] = 1;
    } else {
      units[i] = earned;
    }
  }

  /// The next day the ayah falls a step if it gets no review, as seen on
  /// [today] (the settled state is through yesterday, so a milestone falling
  /// today is still ahead), or null.
  int? deadline(int i, int today) {
    final s = status[i];
    if (s == _notLearned || s == _forgotten) return null;
    final origin = (s == _fading1 || s == _fading2) ? from[i] : s;
    final a = anchor(i);
    if (origin == noStatus || a == none) return null;
    final milestones = <int>[];
    if (origin == _consolidated) {
      milestones.addAll([
        rules.consolidatedFade1,
        rules.consolidatedFade2,
        rules.consolidatedForgotten,
      ]);
    } else if (origin >= _learning1 && origin <= _learning3) {
      final prime = _isPrime(i);
      milestones.addAll([
        rules.fade1(origin, prime: prime),
        rules.fade2(origin, prime: prime),
        rules.drop(origin, prime: prime),
      ]);
    } else {
      return null;
    }
    final elapsed = today - a;
    int? next;
    for (final m in milestones) {
      if (m >= elapsed && (next == null || m < next)) next = m;
    }
    return next == null ? null : a + next;
  }
}
