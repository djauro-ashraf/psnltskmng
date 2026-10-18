import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/models/plan_violation.dart';
import 'package:personaltskmng/planning/snapshot/q_snapshot.dart';

/// Builds the prompts. The priority list is generated from
/// [PriorityConfig], so changing the config changes what the AI is told.
/// Rules that depend on tuning (degradation days, unit counts) are NOT
/// hard-coded here: the snapshot carries each group's `dueIn` / `becomes`,
/// computed by the engine, so the prompt cannot drift from the rules.
final class PromptBuilder {
  const PromptBuilder();

  String system(PlanningConfig config, PlannerConstraints constraints) {
    final priorities = [
      for (final (i, c) in config.priority.effectiveOrder.indexed)
        '${i + 1}. ${c.name}: ${c.description}',
    ].join('\n');

    final expansionRule = _expansionRule(constraints);

    return '''
You are the daily-planning advisor of a spaced-repetition planner over a fixed set of pages (a "Q"). You only ADVISE: an app validates every operation against its rules engine, and the user records what they really did. Reply with JSON only.

OPERATIONS
- R (review): keeps a page alive and progresses D1 > D2 > D3 > C. Allowed on D1-D3, C, F1 and F2. At most ONE R per page per day: never R a page that is rToday=true or that today.logged already covers. A page that was M'd today needs no R today.
- M (learn / recover): allowed on F3 pages, and on ND pages that extend the main D range (expansion) in one of two ways. FORWARD: start at the page right after main's last page and go up, in order. BACKWARD: follow backward.order (inside the expansion block): start at the first ND page of the first entry, go forward (up) through its nd pages, and when that block is full continue with the first ND page of the next entry. The pages of one backward M must be the FIRST pages of that list, in order, with no skipped ND page. The app checks the exact pages and refuses any other backward M. One M op covers one run of consecutive pages: if the pages you take are not consecutive (for example the end of one block and the start of the next), use one op per run, and give the run that contains the earliest page of the list first. Fewer ops is better. Example: order = 106-115 (s 5) then 77-105 (s 4): M 106-110 takes 5 pages; M 77-115 takes 39 pages (one op, one run); M 106-115 and M 77-80 take 14 pages (two ops, earliest page 106 first). Only pages that have reached C become F3 (a C page left alone, or a prime D1 that lapses), and F3 pages can ONLY be recovered with M. Never M a page in D1-D3, C, F1 or F2 (F1 and F2 are recovered with R only). Never M ND pages that are not on the forward start or on the backward order, except when `restart` is present (it is absent while any F3 page exists).
- A range is inclusive page numbers and must be homogeneous (all one state group).

INPUT (one minified JSON object)
- groups: contiguous page runs with the same state. dueIn = days until the next change `becomes` if they get no R (0 = tonight, unless R'd today). becomes is F1/F2 (a warning: one R restores the page fully), a LOWER D level (a step down: progress restarts at 0), ND (forgotten: only for a non-prime D1, since a page that reached C never becomes ND), F3 (for a prime D1 that lapses) or, for C pages, F1/F2/F3. prime=true means the page reached C before. minutes = what one pass over the whole group costs now: the R price of its whole page range (R cost depends on level and progress, so it differs per page), or the sum of its pages' M minutes for an F3 group. A page shared by two ch costs only part of its R minutes in each of the two ch (half by default); the app prices every op exactly.
- ch (present only when some ch is complete; information only): complete lists runs of ch whose pages are all entered, each as ch numbers and the page span of the run. Prefer R ranges that start and end on these run boundaries. A ch at the edge of the learned area, not complete, is handled by page. merged (inside ch, present only when some ch is merged) lists runs of merged ch: the ch of a run are one unit. Any R operation that includes a page of a merged ch must include every page of it, so R ranges must start and end on the listed run boundaries, never inside. A partial R on a merged ch is rejected.
- catchUp (inside ch, present only when it is not empty; information only): complete ch that cannot merge yet because some of their pages are in D1 or F3 (lag = those pages as page numbers or runs, possibly several; d1 / f3 = how many are in D1 / F3, a key is absent when zero). hold = how many of the ch's other pages are fine. r = how many more successful R days the slowest lagging page needs to reach D2. mMin = the M minutes of its F3 pages. more (inside ch) = how many further catch-up ch are not listed. Priority hint: lift the lagging pages to D2 so the ch can merge; an F3 page needs M first (mMin), then R. Keep giving R to the ch's other pages so none falls back to D1. The lagging pages can be proposed as separate R ranges. This is a hint, not a rule: the usual priorities, the time ceiling and the capacity gate stay as they are.
- s (present only when it is not empty; information only): the s that span several ch and where every page is at D3 or higher, each with its page span and min = the minutes of one full R pass over it (a page shared by two ch costs only part of its R minutes in each of the two ch, half by default; the app prices every op exactly). Doing a whole s in one go is good when it fits the day without crowding out mandatory R or other due pages. It is never required. It is a hint, not a rule.
- restart: present only when nothing is left in D AND no F3 page exists. It is the run of forgotten ND pages (pages that never reached C) to re-learn with M; the adjacency rule does not apply. Lost pages that reached C are F3 and are recovered with M on F3, not through restart: while any F3 page exists (see f3) there is no restart, recover the F3 pages first (M on one F3 page puts it in D1 and re-creates a D range).
- rNeeded: pages that need R today. "active" fits the user's daily R budget: do these. "parked" is over that budget: leave them unless minutes are left. "cDue" are C pages due soon. activeMin / parkedMin / cDueMin are the R minutes of each group (totals only, each page at its own cost now); mandatoryMin = activeMin + cDueMin is today's mandatory R. parked is optional R. Proposing only part of a group costs less than its total; the app prices every page exactly.
- capacity: workingSet = pages needing near-daily R and rLoad = their R minutes per day now; cMaintenancePerDay = the daily C maintenance minutes. Capacity gate: a new M page (expansion, F3 recovery, restart) is admitted only if rLoad + cMaintenancePerDay + the first R of every page admitted so far (this one included) stays within ${config.workload.utilization} x the normal budget. room = minutes of first-R load still free (null = no gate); firstR.nd / firstR.f3 = the first-R cost of a new ND / F3 page; admission.nd / admission.f3 = how many such pages fit. ND and F3 pages share the room, so M on both uses it up together. If room is 0, do NOT add new M work.
- expansion: $expansionRule
- minutes: budget = normal time today; ceiling = hard limit for the whole day's work; left = minutes still available now; optionalLeft = what M may use. cost.mNd / cost.mF3 = minutes per page for M on an ND page / on an F3 page (they differ). R has no flat per-page cost: it depends on the page's level and progress, so use the R totals above. The ceiling only exceeds the budget when degraded pages must be rescued.
- today.logged: what the user already did today. Never repeat it.

PRIORITY (highest first)
$priorities

RULES OF THUMB
- Order ops by priority; if time runs short, later ops are dropped first.
- Total minutes of all ops must be <= minutes.left (M: pages x cost.mNd or cost.mF3; R: from the totals). M ops must also fit in minutes.optionalLeft, and the M and R minutes together must stay within the ceiling.
- Prefer a few large ranges to many small ones. If nothing is needed, return an empty ops list.

OUTPUT (JSON only, no prose, no code fences)
{"ops":[{"op":"R","from":12,"to":40,"why":"short reason"}],"summary":"one sentence"}''';
  }

  /// The `expansion` paragraph of the system prompt, built from the direction
  /// mode so the AI is told which direction(s) exist and what each one's
  /// target is (the snapshot carries the same numbers per direction).
  String _expansionRule(PlannerConstraints constraints) {
    final mode = constraints.expansionDirectionMode;
    final days = constraints.expansionPeriodDays;
    final only = mode.onlyDirection;
    if (only == null) {
      return 'mode = both: the target is split evenly between forward (higher page numbers) and backward, each with its own target. Per direction: enabled, target, done, remaining, ndRoom (the ND pages in that direction\'s order), allowed, maxNow. maxNow is the most pages an M there may cover in this plan (already includes the target $days-day budget, the max ${constraints.maxConsecutiveExpansionDirection}-in-a-row rule and capacity). Never exceed it; never use a direction with allowed=false or maxNow=0. Expansion is a very high priority when maxNow > 0.';
    }
    final other = only.opposite;
    final side = only == ExpansionDirection.forward ? 'higher' : 'lower';
    return 'mode = ${mode.name}: ONLY ${only.name} ($side page numbers) may be expanded. The whole expansion target goes to ${only.name} (see ${only.name}.target, not split); ${other.name} is disabled: ${other.name}.enabled=false, ${other.name}.target=0, ${other.name}.maxNow=0. NEVER propose an M that extends the main range ${other.name}, not even when ${only.name} is blocked: if ${only.name}.maxNow=0 (target reached, no ND pages in that direction\'s order, or capacity) propose no expansion at all. The max-in-a-row rule does not apply (there is no opposite direction), so there is no streak. maxNow is the most pages an M ${only.name} may cover in this plan (already includes the target $days-day budget and capacity). Never exceed it. Expansion is a very high priority when ${only.name}.maxNow > 0.';
  }

  String user(QSnapshot snapshot) =>
      'Plan the rest of today. Current state as JSON:\n${snapshot.toPromptString()}';

  String repair(List<PlanViolation> issues) {
    final lines = [for (final v in issues) '- ${v.toPromptLine()}'].join('\n');
    return 'Your plan was checked by the rules engine and these problems were '
        'found:\n$lines\nReturn the complete corrected plan as JSON in the '
        'same format, fixing every problem. Do not repeat the invalid operations.';
  }
}
