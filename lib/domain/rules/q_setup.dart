import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/domain_constants.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/rules/d_range_rules.dart';

/// One row of the first-run setup: the pages [from] to [to] are in [state].
///
/// - [progressUnits]: only for D rows (D1-D3), units already earned in that
///   level; below the units needed to leave it.
/// - [daysSinceR]: days since the last R (and M): `lastR` and `lastM` are
///   today minus this many days. 0 means reviewed today.
/// - [wasConsolidatedBefore]: only for D rows; makes the pages prime. C and F3
///   pages are always prime.
final class SetupRow {
  const SetupRow({
    required this.from,
    required this.to,
    required this.state,
    this.progressUnits = 0,
    this.daysSinceR = 0,
    this.wasConsolidatedBefore = false,
  });

  final int from;
  final int to;
  final PageState state;
  final int progressUnits;
  final int daysSinceR;
  final bool wasConsolidatedBefore;
}

/// What is wrong with the setup rows.
enum SetupProblemKind {
  /// The state is not one of D1, D2, D3, C, F3.
  stateNotAllowed,

  /// `from` is greater than `to`.
  fromAfterTo,

  /// A page is outside 1..604 ([SetupProblem.value] is the offending page).
  pageOutOfBounds,

  /// Progress is below 0.
  progressNegative,

  /// Progress is not below the units needed to leave the level
  /// ([SetupProblem.max] is the largest allowed value).
  progressTooHigh,

  /// Progress is given for a row that is not D.
  progressNotForState,

  /// Days since the last R is below 0.
  daysNegative,

  /// Two rows share pages ([SetupProblem.otherRow] is the second row).
  overlap,

  /// The built Q failed its own check ([SetupProblem.detail] says why). Not
  /// expected for rows that passed the other checks.
  invalidQ,
}

/// One problem, naming its row (1-based, the order the rows were given).
final class SetupProblem {
  const SetupProblem(
    this.kind, {
    this.row,
    this.otherRow,
    this.value,
    this.max,
    this.detail,
  });

  final SetupProblemKind kind;
  final int? row;
  final int? otherRow;
  final int? value;
  final int? max;
  final String? detail;

  /// Plain English, for tests and logs. The UI builds its own localized text
  /// from the fields.
  @override
  String toString() => switch (kind) {
    SetupProblemKind.stateNotAllowed =>
      'row $row: this state is not allowed (use D1, D2, D3, C or F3)',
    SetupProblemKind.fromAfterTo => 'row $row: from is greater than to',
    SetupProblemKind.pageOutOfBounds =>
      'row $row: page $value is outside 1-${ChTable.totalPages}',
    SetupProblemKind.progressNegative => 'row $row: progress cannot be below 0',
    SetupProblemKind.progressTooHigh =>
      'row $row: progress $value is too high (max $max)',
    SetupProblemKind.progressNotForState =>
      'row $row: progress units are only for D rows',
    SetupProblemKind.daysNegative =>
      'row $row: days since the last R cannot be below 0',
    SetupProblemKind.overlap => 'rows $row and $otherRow overlap',
    SetupProblemKind.invalidQ => 'the Q is not valid: $detail',
  };
}

sealed class QSetupResult {
  const QSetupResult();
}

/// The rows built a valid Q.
final class QSetupOk extends QSetupResult {
  const QSetupOk(this.q);

  final Q q;
}

/// The rows have problems; no Q was built.
final class QSetupProblems extends QSetupResult {
  const QSetupProblems(this.problems);

  final List<SetupProblem> problems;
}

/// Builds the first Q from what the user says is learned. Pure and
/// deterministic. Pages in no row are ND.
///
/// - Allowed states: D1, D2, D3, C, F3. C and F3 pages are prime (they reached
///   C); a D row is prime when [SetupRow.wasConsolidatedBefore].
/// - Progress units (D rows only, default 0) must be below the units needed to
///   leave the level: normal D1/D2/D3 = 7/7/14, prime 4/4/7
///   ([DomainConstants]).
/// - `lastR` and `lastM` are today minus [SetupRow.daysSinceR]; the page clock
///   (`degradationAnchor`) then follows the engine's own rule (the latest of
///   them). The Q has `evaluatedThrough` null, so the first day's `catchUp`
///   judges every day through yesterday with the engine's own rules.
/// - The D ranges and the main range are built by the normal rebuild
///   (`rebuildDRanges`): the largest D range is main, ties by
///   [PlannerConstraints.mainTieBreak]. F3 and ND pages are in no D range.
/// - The Q must pass [Q.checkInvariants], else [QSetupProblems] with
///   [SetupProblemKind.invalidQ].
abstract final class QSetup {
  static const int totalPages = ChTable.totalPages;

  static const Set<PageState> allowedStates = {
    PageState.d1,
    PageState.d2,
    PageState.d3,
    PageState.c,
    PageState.f3,
  };

  /// Units needed to leave D level [state] ([prime] or not).
  static int unitsToLeave(PageState state, {required bool prime}) =>
      (prime
          ? DomainConstants.primeProgressionTargetUnits
          : DomainConstants.progressionTargetUnits)[state]!;

  /// The largest progress a D row may have.
  static int maxProgress(PageState state, {required bool prime}) =>
      unitsToLeave(state, prime: prime) - 1;

  /// The problems of [rows] without building a Q (empty = the rows are fine).
  static List<SetupProblem> problemsOf(List<SetupRow> rows) {
    final problems = <SetupProblem>[];
    final validRange = <int>[];
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final n = i + 1;
      var rangeOk = true;
      if (!allowedStates.contains(r.state)) {
        problems.add(SetupProblem(SetupProblemKind.stateNotAllowed, row: n));
      }
      if (r.from > r.to) {
        problems.add(SetupProblem(SetupProblemKind.fromAfterTo, row: n));
        rangeOk = false;
      } else {
        if (r.from < 1) {
          problems.add(
            SetupProblem(SetupProblemKind.pageOutOfBounds, row: n, value: r.from),
          );
          rangeOk = false;
        }
        if (r.to > totalPages) {
          problems.add(
            SetupProblem(SetupProblemKind.pageOutOfBounds, row: n, value: r.to),
          );
          rangeOk = false;
        }
      }
      if (r.daysSinceR < 0) {
        problems.add(SetupProblem(SetupProblemKind.daysNegative, row: n));
      }
      if (r.progressUnits < 0) {
        problems.add(SetupProblem(SetupProblemKind.progressNegative, row: n));
      } else if (r.state.isD) {
        final max = maxProgress(r.state, prime: r.wasConsolidatedBefore);
        if (r.progressUnits > max) {
          problems.add(
            SetupProblem(
              SetupProblemKind.progressTooHigh,
              row: n,
              value: r.progressUnits,
              max: max,
            ),
          );
        }
      } else if (r.progressUnits != 0 && allowedStates.contains(r.state)) {
        problems.add(SetupProblem(SetupProblemKind.progressNotForState, row: n));
      }
      if (rangeOk) validRange.add(i);
    }
    for (var a = 0; a < validRange.length; a++) {
      for (var b = a + 1; b < validRange.length; b++) {
        final x = rows[validRange[a]];
        final y = rows[validRange[b]];
        if (x.from <= y.to && y.from <= x.to) {
          problems.add(
            SetupProblem(
              SetupProblemKind.overlap,
              row: validRange[a] + 1,
              otherRow: validRange[b] + 1,
            ),
          );
        }
      }
    }
    return problems;
  }

  /// Builds the Q for [today], or lists the problems.
  static QSetupResult build({
    required String id,
    required List<SetupRow> rows,
    required Day today,
    PlannerConstraints constraints = const PlannerConstraints(),
  }) {
    final problems = problemsOf(rows);
    if (problems.isNotEmpty) return QSetupProblems(problems);

    final pages = [
      for (var n = 1; n <= totalPages; n++) PageRecord(number: n),
    ];
    for (final r in rows) {
      final last = today.plusDays(-r.daysSinceR);
      final prime =
          r.state == PageState.c ||
          r.state == PageState.f3 ||
          r.wasConsolidatedBefore;
      for (var n = r.from; n <= r.to; n++) {
        pages[n - 1] = _record(n, r, last, prime);
      }
    }

    final rebuild = rebuildDRanges(
      pages: pages,
      previous: const [],
      nextRangeId: 1,
      constraints: constraints,
    );
    final q = Q(
      id: id,
      totalPages: totalPages,
      pages: pages,
      dRanges: rebuild.ranges,
      nextRangeId: rebuild.nextRangeId,
    );
    final invalid = q.checkInvariants();
    if (invalid.isNotEmpty) {
      return QSetupProblems([
        SetupProblem(SetupProblemKind.invalidQ, detail: invalid.join('; ')),
      ]);
    }
    return QSetupOk(q);
  }

  /// A page that was M'd and (for a prime page) consolidated once before:
  /// the counters that express "prime" (`cEntries` > 0) and the history the
  /// state needs.
  static PageRecord _record(int n, SetupRow r, Day last, bool prime) {
    switch (r.state) {
      case PageState.c:
        return PageRecord(
          number: n,
          state: PageState.c,
          lastM: last,
          lastR: last,
          mCount: 1,
          stateSince: last,
          dEntries: 1,
          cEntries: 1,
        );
      case PageState.f3:
        return PageRecord(
          number: n,
          state: PageState.f3,
          degradedFrom: PageState.c,
          lastM: last,
          lastR: last,
          mCount: 1,
          stateSince: last,
          missCount: 1,
          dEntries: 1,
          cEntries: 1,
          fEntries: 1,
        );
      default:
        return PageRecord(
          number: n,
          state: r.state,
          lastM: last,
          lastR: last,
          mCount: prime ? 2 : 1,
          progressUnits: r.progressUnits,
          stateSince: last,
          dEntries: prime ? 2 : 1,
          cEntries: prime ? 1 : 0,
          fEntries: prime ? 1 : 0,
        );
    }
  }
}
