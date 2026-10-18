import 'dart:math' as math;

import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/operation.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/merged_spans.dart';
import 'package:personaltskmng/domain/rules/restart_rules.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/facts/planning_facts.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/planning/planners/planner.dart';

/// The backward pages [taken] (the first n entries of the backward list, in
/// list order) as M ranges: the SET of pages sorted and cut into runs of
/// consecutive page numbers, one range per run, ordered by the earliest list
/// entry each run contains (so each op is valid on the Q after the ones before
/// it).
List<PageRange> _backwardRunsInListOrder(List<int> taken) {
  final sorted = [...taken]..sort();
  final runs = PageRange.compress(sorted);
  int firstIndex(PageRange run) {
    for (var i = 0; i < taken.length; i++) {
      if (run.contains(taken[i])) return i;
    }
    return taken.length;
  }

  return [...runs]..sort((a, b) => firstIndex(a).compareTo(firstIndex(b)));
}

/// Deterministic offline planner and the baseline any smarter planner must
/// beat. Valid by construction: every op it emits was applied through the real
/// engine on a running copy of the Q.
///
/// Recovery means: M on F3 pages (pages that have reached C) and, only when
/// nothing is left in D and no F3 page exists, re-entering the most recently
/// forgotten ND pages (pages that never reached C: restart). F3 recovery
/// always comes first.
///
/// Policy in one paragraph: R keeps existing pages alive and is mandatory;
/// M (F3 recovery, expansion) adds new daily R load, so it is only admitted
/// while the working set fits the user's time (per-page capacity gate) and it
/// never spends minutes that mandatory R still needs. Every minute is the
/// real per-page cost (`TimeModel`): each page is priced by its own state,
/// progress and prime flag as it is when planning. When the working set exceeds
/// capacity, a stable focus set (most advanced pages first) is worked every
/// day instead of rotating thin R over everything, which would restore pages
/// without ever progressing them. Priority order comes from [PriorityConfig].
final class RuleBasedPlanner implements Planner {
  const RuleBasedPlanner({required this.engine});

  final RulesEngine engine;

  static const String sourceId = 'rule_based';

  @override
  Future<PlanCandidate> plan(PlanRequest request) async => planSync(
    q: request.q,
    day: request.day,
    facts: request.facts,
    config: request.config,
    constraints: request.constraints,
  );

  PlanCandidate planSync({
    required Q q,
    required Day day,
    required PlanningFacts facts,
    required PlanningConfig config,
    required PlannerConstraints constraints,
  }) {
    final time = config.time;
    final order = config.priority.effectiveOrder;

    var running = q;
    var used = 0.0;
    var admissionRoom = facts.admissionRoomMinutes;
    final ops = <PlanOp>[];
    // Merged ch that were due but whole did not fit the minutes left: left
    // out entirely (a partial R would be rejected), reported in the rationale.
    final leftOut = <MergedChSpan>[];

    List<PageRecord> pagesOf(PageRange range) => [
      for (final n in range.pages) running.page(n),
    ];

    bool commit(Operation op, PageRange range, String note) {
      // Priced before the op changes the pages: as they are when planning
      // (the op price, shared pages weighted; ranges here are real pages).
      final cost = time.opMinutes(running, op, range);
      final result = op == Operation.m
          ? engine.applyM(q: running, range: range, today: day)
          : engine.applyR(q: running, range: range, today: day, successful: true);
      final next = result.valueOrNull;
      if (next == null) return false;
      running = next;
      used += cost;
      ops.add(PlanOp(operation: op, range: range, note: note));
      return true;
    }

    // R on pages already ranked best-first, as many as [available] minutes pay
    // (each page at its own R cost; counting stops at the first that does not
    // fit, so the best-first focus set stays stable). A merged ch is one unit:
    // taken or left out as a whole, its cost the sum of its pages' R minutes,
    // so no range ever starts or ends inside its owned pages.
    void spendR(List<int> ranked, String note, double available) {
      var left = available;
      final taken = <int>[];
      for (final unit in MergedSpans.units(running, ranked)) {
        final cost = time.rPagesPrice(running, unit);
        if (cost > left + 1e-9) {
          final block = MergedSpans.blockOfPage(running, unit.first);
          if (block != null && !leftOut.any((b) => b.ch == block.ch)) {
            leftOut.add(block);
          }
          break;
        }
        left -= cost;
        taken.addAll(unit);
      }
      if (taken.isEmpty) return;
      taken.sort();
      for (final range in PageRange.compress(taken)) {
        commit(Operation.r, range, note);
      }
    }

    double optionalAvailable(double reserve) => math.max(
      0.0,
      math.min(
        facts.remainingMinutes - used - reserve,
        facts.optionalRoomMinutes - used,
      ),
    );

    // How many of [pages] (an M's pages, in the order they would be admitted)
    // fit both the M minutes left ([available]) and the capacity gate (their
    // first R against [admissionRoom]). Pages are admitted one by one until
    // the next one does not fit.
    int admit(List<PageRecord> pages, double available) {
      var minutesLeft = available;
      var roomLeft = admissionRoom;
      var count = 0;
      for (final page in pages) {
        final m = time.mMinutesOf(page);
        // Read on `running` as it is now, before the M is applied.
        final first = time.firstRLoadOf(running, page);
        if (m > minutesLeft + 1e-9 || first > roomLeft + 1e-9) break;
        minutesLeft -= m;
        roomLeft -= first;
        count++;
      }
      return count;
    }

    void recoverF3(double reserve) {
      var available = optionalAvailable(reserve);
      for (final run in running.rangesInState(PageState.f3)) {
        final n = admit(pagesOf(run), available);
        if (n <= 0) continue;
        final range = PageRange(run.start, run.start + n - 1);
        final pages = pagesOf(range);
        // Before the op: the weight is read on the Q as it is now, and the room
        // is reduced by this same number once the op has changed `running`.
        final firstLoad = time.firstRLoadTotal(running, pages);
        if (commit(Operation.m, range, 'recover F3')) {
          admissionRoom -= firstLoad;
          available -= time.totalMinutes(Operation.m, pages);
        }
      }
      // Nothing left in D and no F3 page left (`RestartRules` offers nothing
      // while any F3 page exists, and recovering one re-creates a D range):
      // only forgotten pages that never reached C remain, so re-learn the most
      // recently forgotten run, or the Q could never start again.
      final restart = RestartRules.candidate(running);
      if (restart != null) {
        final n = admit(pagesOf(restart), available);
        if (n > 0) {
          final range = PageRange(restart.start, restart.start + n - 1);
          final pages = pagesOf(range);
          final firstLoad = time.firstRLoadTotal(running, pages);
          if (commit(Operation.m, range, 'restart: re-learn forgotten pages')) {
            admissionRoom -= firstLoad;
          }
        }
      }
    }

    // Direction mode is applied by [ExpansionFacts]: a disabled direction has
    // maxPages 0 and so is never a candidate, and in a single-direction mode
    // the enabled one carries the whole target. A blocked enabled direction
    // means no expansion at all (no fallback to the other side).
    void expand(double reserve) {
      final available = optionalAvailable(reserve);
      final ex = ExpansionFacts.compute(
        q: running,
        today: day,
        config: config,
        constraints: constraints,
      );
      final main = ex.main;
      if (main == null) return;
      final directions = [
        ExpansionDirection.forward,
        ExpansionDirection.backward,
      ].where((d) => ex.of(d).maxPages > 0).toList();
      directions.sort((a, b) {
        final byRemaining = ex
            .of(b)
            .targetRemaining
            .compareTo(ex.of(a).targetRemaining);
        if (byRemaining != 0) return byRemaining;
        // Prefer switching direction: continuing feeds the 3-in-a-row limit.
        final last = running.expansion.lastDirection;
        final byStreak = (a == last ? 1 : 0).compareTo(b == last ? 1 : 0);
        if (byStreak != 0) return byStreak;
        return a.index.compareTo(b.index);
      });
      for (final d in directions) {
        if (d == ExpansionDirection.backward &&
            running.totalPages == ChTable.totalPages) {
          // Backward on the 604-page Q: the pages come from the backward s
          // list (ExpansionFacts.backwardPages). The first n entries are taken
          // as a SET and cut into runs of consecutive page numbers, one M op
          // per run, the run with the earliest list entry first; each op is
          // valid on the Q after the ones before it. The pages
          // already taken earlier in this plan are no longer ND, so they are
          // not in the list.
          final list = ExpansionFacts.backwardPages(running, main);
          final candidates = [
            for (final n in list.take(ex.of(d).maxPages)) running.page(n),
          ];
          final amount = admit(candidates, available);
          if (amount <= 0) continue;
          final taken = [for (final page in candidates.take(amount)) page.number];
          for (final range in _backwardRunsInListOrder(taken)) {
            final firstLoad = time.firstRLoadTotal(running, pagesOf(range));
            if (!commit(Operation.m, range, 'expand ${d.name}')) break;
            admissionRoom -= firstLoad;
          }
          return;
        }
        // The ND pages next to the main range, nearest first (forward, and
        // backward on a Q that is not 604 pages).
        final candidates = [
          for (var i = 1; i <= ex.of(d).maxPages; i++)
            running.page(
              d == ExpansionDirection.forward ? main.end + i : main.start - i,
            ),
        ];
        final amount = admit(candidates, available);
        if (amount <= 0) continue;
        final range = d == ExpansionDirection.forward
            ? PageRange(main.end + 1, main.end + amount)
            : PageRange(main.start - amount, main.start - 1);
        final pages = pagesOf(range);
        final firstLoad = time.firstRLoadTotal(running, pages);
        if (commit(Operation.m, range, 'expand ${d.name}')) {
          admissionRoom -= firstLoad;
        }
        return; // one expansion per plan; "more work" adds the other side (mode both)
      }
    }

    for (var i = 0; i < order.length; i++) {
      final cls = order[i];
      var reserve = 0.0;
      if (config.priority.protectMandatoryWork && !cls.isMandatory) {
        for (var j = i + 1; j < order.length; j++) {
          reserve += switch (order[j]) {
            WorkClass.workingSetR => facts.activeRMinutes,
            WorkClass.maintainC => facts.cDueRMinutes,
            _ => 0.0,
          };
        }
      }
      switch (cls) {
        case WorkClass.recoverF3:
          recoverF3(reserve);
        case WorkClass.expand:
          expand(reserve);
        case WorkClass.workingSetR:
          spendR(
            facts.activeR,
            'keep D/F pages progressing',
            facts.remainingMinutes - used,
          );
        case WorkClass.maintainC:
          spendR(facts.cDue, 'C maintenance', facts.remainingMinutes - used);
      }
    }

    // Spare minutes (never the stretch): R on pages beyond capacity.
    spendR(
      facts.parkedR,
      'spare time',
      math.min(facts.remainingMinutes - used, facts.optionalRoomMinutes - used),
    );

    return PlanCandidate(
      ops: ops,
      source: sourceId,
      rationale: leftOut.isEmpty
          ? 'Offline rule-based plan.'
          : 'Offline rule-based plan. Left out whole because it does not fit '
                'the minutes left: ${[for (final b in leftOut) 'ch ${b.ch} (pages ${b.pages})'].join(', ')}.',
    );
  }
}
