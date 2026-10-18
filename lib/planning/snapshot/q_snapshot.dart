import 'dart:convert';

import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/models/time_model.dart';
import 'package:personaltskmng/domain/rules/catch_up.dart';
import 'package:personaltskmng/domain/reference/ch_status.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/domain/rules/degradation_rules.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/facts/planning_facts.dart';
import 'package:personaltskmng/planning/models/logged_op.dart';
import 'package:personaltskmng/planning/models/minutes.dart';

/// What the AI sees (and what is stored for later learning): a compact JSON
/// summary, never 604 raw pages.
final class QSnapshot {
  const QSnapshot(this.json);

  final Map<String, Object?> json;

  String toPromptString() => jsonEncode(json);
}

final class _PageInfo {
  const _PageInfo({
    required this.number,
    required this.state,
    required this.prime,
    required this.dueIn,
    required this.becomes,
    required this.rToday,
    required this.minutes,
  });

  final int number;
  final PageState state;
  final bool prime;
  final int? dueIn;
  final PageState? becomes;
  final bool rToday;

  /// The M cost of this page for an F3 page, 0 otherwise. Only F3 groups sum
  /// it; the minutes of any other group are the op price of its range.
  final double minutes;
}

/// A run of contiguous pages sharing state, prime flag and deadline.
final class _Group {
  _Group(_PageInfo first)
    : state = first.state,
      prime = first.prime,
      start = first.number,
      end = first.number,
      pages = 1,
      minDue = first.dueIn,
      becomes = first.becomes,
      allRToday = first.rToday,
      minutes = first.minutes,
      _lastDue = first.dueIn,
      _lastBecomes = first.becomes,
      _lastRToday = first.rToday;

  final PageState state;
  final bool prime;
  final int start;
  int end;
  int pages;
  int? minDue;
  PageState? becomes;
  bool allRToday;

  /// Sum of the pages' [_PageInfo.minutes] (M minutes; used for F3 groups
  /// only).
  double minutes;
  int? _lastDue;
  PageState? _lastBecomes;
  bool _lastRToday;

  bool accepts(_PageInfo i, {required bool coarse}) =>
      i.number == end + 1 &&
      i.state == state &&
      i.prime == prime &&
      (coarse ||
          (i.dueIn == _lastDue &&
              i.becomes == _lastBecomes &&
              i.rToday == _lastRToday));

  void add(_PageInfo i) {
    end = i.number;
    pages++;
    final due = i.dueIn;
    if (due != null && (minDue == null || due < minDue!)) {
      minDue = due;
      becomes = i.becomes;
    }
    allRToday = allRToday && i.rToday;
    minutes += i.minutes;
    _lastDue = i.dueIn;
    _lastBecomes = i.becomes;
    _lastRToday = i.rToday;
  }
}

/// Builds a [QSnapshot]. Requires a Q settled through yesterday (`catchUp`):
/// a snapshot of an unsettled Q would show pages that have already degraded
/// as if they had not, so this refuses instead of guessing.
final class SnapshotBuilder {
  const SnapshotBuilder();

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  QSnapshot build({
    required Q q,
    required Day day,
    required PlanningFacts facts,
    required List<LoggedOp> logged,
    required PlanningConfig config,
    required PlannerConstraints constraints,
    int planIndex = 0,
  }) {
    if (!isSettledFor(q, day)) {
      throw StateError(
        'Q is only evaluated through ${q.evaluatedThrough}; call '
        'RulesEngine.catchUp before building a snapshot for $day.',
      );
    }
    final time = config.time;
    final settled = day.plusDays(-1);

    final infos = <_PageInfo>[];
    for (final p in q.pages) {
      if (p.state == PageState.nd) continue;
      final milestone = p.state == PageState.f3
          ? null
          : DegradationRules.nextMilestone(p, settled);
      infos.add(
        _PageInfo(
          number: p.number,
          state: p.state,
          prime: isPrime(p),
          dueIn: milestone?.day.daysSince(day),
          becomes: milestone?.becomes,
          rToday: p.lastR == day,
          minutes: p.state == PageState.f3 ? time.mMinutesOf(p) : 0.0,
        ),
      );
    }

    var groups = _group(infos, coarse: false);
    var coarse = false;
    if (groups.length > config.maxSnapshotGroups) {
      groups = _group(infos, coarse: true);
      coarse = true;
    }
    var truncated = false;
    if (groups.length > config.maxSnapshotGroups) {
      groups = groups.sublist(0, config.maxSnapshotGroups);
      truncated = true;
    }

    Map<String, Object?> groupJson(_Group g) {
      final becomes = g.becomes;
      return {
        'state': g.state.name.toUpperCase(),
        'prime': g.prime,
        'range': PageRange(g.start, g.end).toString(),
        'pages': g.pages,
        if (g.minDue != null) 'dueIn': g.minDue,
        if (becomes != null) 'becomes': becomes.name.toUpperCase(),
        'rToday': g.allRToday,
        // F3: the sum of the pages' M minutes. Any other state: the op price
        // of the whole range, on the Q as it is now (shared pages weighted).
        'minutes': jsonMinutes(
          g.state == PageState.f3
              ? g.minutes
              : time.rOpPrice(q, PageRange(g.start, g.end)),
        ),
      };
    }

    Map<String, Object?> directionJson(ExpansionDirection d) {
      final f = facts.expansion.of(d);
      final mainRange = facts.expansion.main;
      // Backward only: the first 3 s blocks that still have ND pages, in
      // learning order (604-page Q, backward enabled, a main range exists).
      final order = d == ExpansionDirection.backward &&
              f.enabled &&
              mainRange != null
          ? _backwardOrder(q, mainRange)
          : const <Map<String, Object?>>[];
      return {
        'enabled': f.enabled,
        'target': f.target,
        'done': f.doneInPeriod,
        'remaining': f.targetRemaining,
        'ndRoom': f.ndRoom,
        'allowed': f.allowed,
        'maxNow': facts.maxExpansionNow(d),
        if (order.isNotEmpty) 'order': order,
      };
    }

    final tracker = q.expansion;
    final counts = {
      for (final e in q.stateCounts.entries)
        if (e.value > 0) e.key.name.toUpperCase(): e.value,
    };
    String ranges(Iterable<int> pages) =>
        PageRange.compress(pages.toList()..sort()).join(',');

    // The capacity gate in the AI's terms: the room left for the first R of
    // new M pages, the first-R cost of an ND and of an F3 page, and how many
    // of each fit (they share the room).
    final room = facts.admissionRoomMinutes;
    final gateOff = room == PlanningFacts.unlimitedAdmissionRoom;
    final firstRNd = time.firstRMinutes(prime: false);
    final firstRF3 = time.firstRMinutes(prime: true);
    int fits(double first) => (room / first + 1e-9).floor();

    final chRuns = _completeChRuns(q);
    final sHints = _sHints(q, time);
    final mergedRuns = [
      for (final run in facts.mergedRuns)
        {'ch': run.chText, 'pages': run.pages.toString()},
    ];
    // Catch-up ch (from the planning facts): complete, not merged, with pages
    // in D1 or F3. d1 / f3 keys only when not zero, mMin only with F3 pages.
    final catchUp = [
      for (final g in facts.catchUp.entries)
        {
          'ch': g.ch,
          'lag': g.lagText,
          if (g.d1 > 0) 'd1': g.d1,
          if (g.f3 > 0) 'f3': g.f3,
          'hold': g.hold,
          'r': g.r,
          if (g.mMinutes != null) 'mMin': jsonMinutes(g.mMinutes!),
        },
    ];

    final json = <String, Object?>{
      'date': day.toString(),
      'weekday': _weekdays[day.weekday - 1],
      'plan': planIndex + 1,
      'pages': q.totalPages,
      'counts': counts,
      'groups': [for (final g in groups) groupJson(g)],
      if (coarse) 'groupsMerged': true,
      if (truncated) 'groupsTruncated': true,
      // Information only, nothing is enforced; both are omitted when empty.
      // `merged` (runs of merged ch, a subset of the complete ones) only when
      // some ch is merged. `catchUp` (complete ch that cannot merge yet) only
      // when there is one, and `more` only when entries were cut.
      if (chRuns.isNotEmpty || mergedRuns.isNotEmpty || catchUp.isNotEmpty)
        'ch': {
          'complete': chRuns,
          if (mergedRuns.isNotEmpty) 'merged': mergedRuns,
          if (catchUp.isNotEmpty) 'catchUp': catchUp,
          if (facts.catchUp.more > 0) 'more': facts.catchUp.more,
        },
      if (sHints.isNotEmpty) 's': sHints,
      'rNeeded': {
        'active': ranges(facts.activeR),
        'parked': ranges(facts.parkedR),
        'cDue': ranges(facts.cDue),
        'activeMin': jsonMinutes(facts.activeRMinutes),
        'parkedMin': jsonMinutes(facts.parkedRMinutes),
        'cDueMin': jsonMinutes(facts.cDueRMinutes),
        'mandatoryMin': jsonMinutes(facts.mandatoryMinutes),
      },
      'f3': ranges(facts.f3Pages),
      if (facts.restartRange != null) 'restart': facts.restartRange.toString(),
      'atRiskTonight': facts.atRiskTonight.join(','),
      'expansion': {
        'main': facts.expansion.main?.toString(),
        'mode': facts.expansion.mode.name,
        'perDirectionTarget': facts.expansion.targetPerDirection,
        'periodDays': facts.expansion.periodDays,
        'forward': directionJson(ExpansionDirection.forward),
        'backward': directionJson(ExpansionDirection.backward),
        // The alternation rule only exists in mode `both`.
        if (!facts.expansion.mode.isSingleDirection)
          'streak': {
            'direction': tracker.lastDirection?.name,
            'count': tracker.consecutive,
            'max': constraints.maxConsecutiveExpansionDirection,
          },
      },
      'capacity': {
        'workingSet': facts.workingSetPages,
        'rLoad': jsonMinutes(facts.workingSetLoadMinutes),
        'cPages': facts.cPages,
        'cMaintenancePerDay': jsonMinutes(facts.cMaintenanceMinutesPerDay),
        'room': gateOff ? null : jsonMinutes(room),
        'firstR': {
          'nd': jsonMinutes(firstRNd),
          'f3': jsonMinutes(firstRF3),
        },
        'admission': gateOff
            ? null
            : {'nd': fits(firstRNd), 'f3': fits(firstRF3)},
      },
      'minutes': {
        'budget': jsonMinutes(facts.dayBudgetMinutes),
        'spent': jsonMinutes(facts.spentMinutes),
        'ceiling': jsonMinutes(facts.ceilingMinutes),
        'left': jsonMinutes(facts.remainingMinutes),
        'optionalLeft': jsonMinutes(
          facts.optionalRoomMinutes < facts.remainingMinutes
              ? facts.optionalRoomMinutes
              : facts.remainingMinutes,
        ),
        'stretched': facts.stretched,
      },
      // M costs depend on the page; R costs depend on level and progress, so
      // only totals are given (rNeeded.*Min, groups[].minutes).
      'cost': {
        'mNd': jsonMinutes(time.mMinutesNd),
        'mF3': jsonMinutes(time.mMinutesF3),
      },
      'today': {'logged': [for (final l in logged) l.toSnapshotJson()]},
      'priority': [
        for (final c in config.priority.effectiveOrder) c.name,
      ],
    };
    return QSnapshot(json);
  }

  /// The runs of consecutive COMPLETE ch ([ChStatus.complete]): the ch
  /// numbers (`'12-13'`, or `'13'` for one ch) and the page span of the run,
  /// from the first OWNED page of its first ch to the last OWNED page of its
  /// last ch (owned pages tile the Q, so the span is contiguous). Empty for a
  /// Q the ch table does not describe and when no ch is complete.
  List<Map<String, Object?>> _completeChRuns(Q q) {
    if (!ChStatus.covers(q)) return const [];
    final status = ChStatus.all(q);
    final runs = <Map<String, Object?>>[];
    var i = 0;
    while (i < status.length) {
      if (!status[i].complete) {
        i++;
        continue;
      }
      var j = i;
      while (j + 1 < status.length && status[j + 1].complete) {
        j++;
      }
      final first = status[i].ch;
      final last = status[j].ch;
      runs.add({
        'ch': first == last ? '$first' : '$first-$last',
        'pages': _ownedSpan(first, last).toString(),
      });
      i = j + 1;
    }
    return runs;
  }

  /// The s that touch two or more ch and are [SStatus.allAtLeastD3]: the s
  /// number, its page span (owned pages, like the ch runs) and the minutes of
  /// one R pass over that span (`TimeModel.rOpPrice`: every page priced as it
  /// is now, shared pages weighted). Single-ch s
  /// are left out (the ch runs cover them). At most 20 s qualify. Empty for a
  /// Q the ch table does not describe.
  List<Map<String, Object?>> _sHints(Q q, TimeModel time) {
    if (!ChStatus.covers(q)) return const [];
    final out = <Map<String, Object?>>[];
    for (final s in SStatus.all(q)) {
      if (s.chOfS.length < 2 || !s.allAtLeastD3) continue;
      final span = _ownedSpan(s.chOfS.first, s.chOfS.last);
      out.add({
        's': s.s,
        'pages': span.toString(),
        'min': jsonMinutes(time.rOpPrice(q, span)),
      });
    }
    return out;
  }

  /// The first 3 s blocks of the backward expansion of [main] that still have
  /// ND pages, in learning order (`STable.backwardBlock`, from `main.start`
  /// down). Each entry: `s`, `block` (the block's pages) and `nd` (its ND
  /// pages), as page range text like the other ranges of the snapshot. A block
  /// without an ND page is not listed. Empty for a Q that is not 604 pages.
  List<Map<String, Object?>> _backwardOrder(Q q, PageRange main) {
    if (q.totalPages != ChTable.totalPages) return const [];
    final out = <Map<String, Object?>>[];
    var start = main.start;
    while (out.length < 3 && start >= 2) {
      final block = STable.backwardBlock(start)!;
      final nd = [
        for (final page in block.pages.pages)
          if (q.page(page).state == PageState.nd) page,
      ];
      if (nd.isNotEmpty) {
        out.add({
          's': block.s,
          'block': block.pages.toString(),
          'nd': PageRange.compress(nd).join(','),
        });
      }
      start = block.pages.start;
    }
    return out;
  }

  /// First owned page of ch [first] to last owned page of ch [last].
  PageRange _ownedSpan(int first, int last) {
    final table = ChTable.instance;
    return PageRange(
      table.ownedPagesOf(first).first,
      table.ownedPagesOf(last).last,
    );
  }

  List<_Group> _group(List<_PageInfo> infos, {required bool coarse}) {
    final out = <_Group>[];
    _Group? current;
    for (final info in infos) {
      final g = current;
      if (g != null && g.accepts(info, coarse: coarse)) {
        g.add(info);
      } else {
        final next = _Group(info);
        out.add(next);
        current = next;
      }
    }
    return out;
  }
}
