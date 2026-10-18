# RULES

The rules the code implements. Numbers live in `lib/domain/models/domain_constants.dart`
and `planner_constraints.dart`; behaviour lives in `lib/domain/rules/`. If this file and the
code disagree, the code is wrong or this file is stale: fix one of them.

## States

`ND` (never reached C: not learned yet, or forgotten), `D1`, `D2`, `D3` (learning levels),
`C` (consolidated), `F1`, `F2`, `F3` (degraded). A page in F remembers the level it degraded from.

- **Prime**: a page that has reached C at least once. Stays prime for good. A prime page
  never becomes ND: it ends in F3 instead, so ND means "never reached C".
- A page in D1-D3, C, F1 or F2 belongs to a **D range**. ND and F3 pages do not.

## Operations

- **M** (enter or recover): allowed ONLY on ND pages and on F3 pages. Not on D1-D3, C, F1
  or F2.
  - ND -> D1, progress 0 (also for pages that were learned once and forgotten).
  - F3 -> D1, progress 0 (the page stays prime).
  - F1/F2 are recovered by R only, never by M.
- **R** (maintain or progress): allowed on D1-D3, C, F1, F2. Not on ND or F3.
  - D: earns 1 unit (see Progression).
  - C: refreshes the page, nothing else.
  - F1/F2: restores the level it degraded from, progress kept, no unit earned.
- **L** (R plus a marker): logged by the user only, see the L section.
- A range is rejected as a whole if any page in it is not eligible.
- **At most one successful R per page per day.** An unsuccessful R (and L) on an R-eligible
  page is accepted and recorded, and changes nothing. On an ND or F3 page it is rejected like
  any R.
- `applyM` / `applyR` / `applyL` first **settle through yesterday** (`catchUp`): degradation is judged for
  every day before today and never for today, so an R today counts as progression.
  `advanceToDay(today)` judges today as complete (end-of-day).

## L (R plus a marker)

L is an action the user logs. It is **R plus a marker**; the marker is only an indication for
the user to interpret. No rule, planner, cost or capacity gate reads it.

- **Effect.** A successful L does everything a successful R does to the page: same
  eligibility (D1-D3, C, F1, F2; not ND, not F3; a range is rejected as a whole), same
  progress or restore effect, same tolerance and penalties. It also sets the page's last-L day.
- **Unsuccessful L**: on an R-eligible page it is accepted and recorded, changes nothing and
  sets no marker; on an ND or F3 page it is rejected like any R.
- **One R per page per day.** If a page already had a successful R today, an L on it is still
  accepted and sets the marker, but its R part adds nothing (no second unit, no error). An R
  after an L the same day is rejected by the one-per-day rule, because the L counted as that
  day's R.
- **Marker.** Each page remembers the day of its last L (or nothing). A page is **L-active**
  on a day when it has a last-L day and fewer than `lMonthDays` days have passed since (the L
  day is day 0; before that day it is not active). `lMonthDays` is a setting
  (`PlannerConstraints.lMonthDays`, default 30). Expiry is derived from the last-L day; there
  is no daily transition. The marker is cleared when a page becomes ND or F3, and a page
  recovered from F3 (or M'd from ND) starts without it. A step-down to a lower D level keeps it.
- **Not proposable.** Planners and the AI never propose L. The parser has no L, and a plan
  containing an L is rejected by the validator (`operationNotProposable`). A logged L is shown
  to the AI as the R it contains; the marker is never in the AI's data.
- **Display.** One function, `LRules.label(page, day, lMonthDays)`: for D1-D3, C, F1 and F2 a
  capital while the page is L-active ("D2", "C", "F1") and lowercase when not ("d2", "c",
  "f1"); ND and F3 stay "ND" and "F3". Planning and the AI keep the plain domain letters.
- **Cost.** L costs the same as R: it is priced as R in the time model (its `baseOperation`).
- **Merged ch.** On a merged ch, L is all or nothing like R (see Merged ch): one marker for the
  whole ch. The marker stays per page (last-L day), set on every owned page at once.

## Progression (D1 -> D2 -> D3 -> C)

Units needed to leave a level:

| | D1 | D2 | D3 |
|---|---|---|---|
| normal | 7 | 7 | 14 |
| prime | 4 | 4 | 7 |

Gap = days since the page's clock start (see Degradation). Tolerated gap (days) for the unit to
count without penalty:

| | D1 | D2 | D3 |
|---|---|---|---|
| normal | 1 | 1 | 2 |
| prime | 2 | 2 | 3 |

A gap beyond tolerance that also exceeds the forgiveness window costs units (never below 0),
and counts a miss. Forgiveness (days): D1 1, D2 2, D3 0. Penalty (units): D1 2, D2 1, D3 2.
Reaching C counts one C entry.

## Degradation (days without R)

**Clock start** = the latest of the page's last M, last successful R, and the day it last
stepped down. Day counts below are measured from it. A page is judged at the end of the day
that completes the count, so an R on that day still saves it.

**D pages: warnings, then one level down.** D2 and D3 step down to D1. D1 falls to ND, except a
prime D1, which becomes F3 instead (a page that has reached C never becomes ND). D2 and D3
never jump straight to F3.

| level | F1 | F2 | then, still no R |
|---|---|---|---|
| D1 | 1 | 2 | ND at 3 |
| D2 | 2 | 3 | steps down to D1 at 4 |
| D3 | 3 | 5 | steps down to D2 at 6 |

Prime pages:

| level | F1 | F2 | then, still no R |
|---|---|---|---|
| D1 | 2 | 3 | F3 at 4 |
| D2 | 3 | 4 | steps down to D1 at 5 |
| D3 | 4 | 7 | steps down to D2 at 8 |

- An R during F1/F2 restores the level fully (M is not allowed on F1/F2).
- A step-down: progress restarts at 0, the clock restarts on the day of the step-down, the
  lower level's day counts apply, history and prime status are kept. Only D1 leaves D: a normal
  D1 falls to ND, a prime D1 becomes F3 (remembering D1). Its history (counters, last M/R) is
  kept, but its progress is gone.
- Guarantee (tested): the time to lose a page is strictly D1 < D2 < D3 < C, and a prime D3 never
  outlasts C's F3. "Lose" means ND for a normal page and F3 for a prime page (C is always prime
  and is lost at F3). Normal: D1 3, D2 7, D3 13 days. Prime: D1 4, D2 9, D3 17 days. C: 18.

**C pages**: F1 at 8 days, F2 at 14, F3 at 18. C never steps down and never becomes ND.
F3 exists only for pages that have reached C (from C, or from a prime D1 lapse) and is the only
level that needs M. F3 is not part of any D range, R is not allowed on it, and M puts it in D1.

Degradation is computed from elapsed days, so one long gap gives exactly the result of
evaluating every day.

## D ranges

Rebuilt from page states after every change; never stored independently. Overlapping or
adjacent runs merge. When a range splits (pages leaving it as ND or F3), the larger fragment
is the main range; ties go to the lower pages (configurable). Re-joining pages reconnects it.

## Expansion

- An M on ND pages is an **expansion** in one of two ways (forward = higher page numbers,
  backward = lower). **Forward**: the M starts at most at `main.end + 1` and reaches past
  `main.end` (next to the end of the main range). **Backward**: it follows the s block list (see
  Backward expansion by s): the SET of its pages equals the SET of the first k entries of
  `backwardCandidates(q, main.start, k)`, k = its number of pages. The Q used is the Q BEFORE the
  op. A Q that is not 604 pages has no s table and keeps the old backward rule (the M ends at
  `main.start - 1` and starts lower). This includes pages that were forgotten. Any other M on ND
  pages is legal and is not counted as an expansion (the log is the truth). The main range does
  not change while a backward block grows (the old main keeps its identity).
- **Direction mode** (a setting, `PlannerConstraints.expansionDirectionMode`): `both`
  (default), `forwardOnly` or `backwardOnly`. It says which direction(s) planning may expand.
- Mode `both` (default): at most **3 consecutive expansions in the same direction**; the
  opposite direction must follow, unless it is blocked (then the same direction is allowed).
  This is a hard rule of the engine.
- Mode `forwardOnly` / `backwardOnly`: only that direction is planned. There is no opposite
  direction, so the 3-in-a-row rule does not apply. If the enabled direction is blocked (edge
  of the Q, or no ND page next to the main range) there is simply no expansion: the other
  direction is never a fallback.
- Target: 10 pages per 7 days, tracked per direction. In `both` it is split evenly (5 forward
  + 5 backward). In a single-direction mode the whole target (10) goes to the enabled
  direction and the other direction gets 0. It is a target, not a limit. M on non-adjacent ND
  pages is legal in the engine (it makes a separate, non-main D range) and is not an
  expansion.
- The mode constrains **planning only** (see Planning). The engine never rejects a manually
  logged expansion in a disabled direction: it is recorded as a normal expansion (and counts
  in that direction's tracking). The 3-in-a-row rule is not applied to logs in a
  single-direction mode.

## Restart

Restart is offered only when **there is no D range, no F3 page exists, and forgotten ND pages
exist**. Then the candidate to re-learn is the run of forgotten ND pages (ND with M history)
around the most recently touched one (ties: lowest page). M on it is an ordinary M on ND pages.
It is only a suggestion: with no D range an M on any ND range is accepted.
Forgotten ND pages never reached C; lost prime pages are F3 and are recovered by M on F3 (F3
recovery), not by restart. **While any F3 page exists, recovering F3 pages comes first and
restart is not offered**: M on one F3 page puts it in D1, which re-creates a D range.

## Planning (advice only)

The AI and the rule-based planner only propose. Nothing changes a Q until the user logs it,
and the log is the truth. A proposal is valid only if every operation passes the rules above
when dry-run through the engine, plus:

- M on ND pages: when a main D range exists, it must follow the expansion rules (forward next to
  `main.end`, or backward along the s block list; `notAdjacentToMain` says where each must
  start, and the first backward page with its s and pages; within the direction mode, the target and the alternation
  rule). When no D range exists, an M on any ND range is accepted, because the user may start
  anywhere (for example the very first M of a fresh Q); the restart range (offered only when
  no D range and no F3 page exists) is only a suggestion. An M range is all ND or all F3, never
  mixed.
- Expansion per direction stays within the target remaining for the rolling period.
- Expansion only goes in an enabled direction (direction mode). A proposed expansion in the
  disabled direction is rejected, like any other planning target. Planners (rule-based and AI)
  propose only the enabled direction, with the whole target, and nothing when it is blocked.
  The AI is told the mode and the per-direction targets in its data and its prompt.
- **Capacity gate** (a per-page check): new M work (expansion, F3 recovery, restart) is
  admitted one page at a time, in the planner's order, and a page is admitted only if

  `R load of the working set + C maintenance load + first R of every page admitted so far,
  this one included  <=  0.9 x budget`

  - *R load of the working set*: every D1-D3 page and every F1/F2 page that came from D, each
    priced at its own R cost now (state, progress, prime flag; see Time model), times the
    shared-page load weight (see Shared pages: half time).
  - *C maintenance load*: every page that came from C (C, and F1/F2 from C) priced at C's R
    cost (times the same weight), spread over the days between maintenance R's (7 minus the
    lead day).
  - *First R* of a newly admitted page: R at D1 with 0 progress for that page's prime flag (20
    min for a normal page, 10 for a prime page, with the defaults), times the same weight, read
    on the Q before the M.
  - The budget is the normal budget (extra minutes offered later in the day do not raise it).
    Admission stops at the first page that does not fit. The gate can be switched off.
  - F3 recovery and restart go through the same gate, like expansion.
  - The same 0.9 x budget (minus C maintenance, minus the load already done today) decides
    which working-set pages are `active` today (best first, as many as fit) and which are
    `parked` (R'd only with spare minutes).
- **Time**: total minutes of a day's work (M and R together, every page at its real cost, the
  shared pages weighted for R) never exceed the ceiling. The ceiling is the budget, except when degraded pages exist: then
  it may reach `1.5 x budget` (never above an optional hard maximum), and only mandatory R may
  use the extra. M work only uses the normal budget. The capacity gate is in addition to this
  ceiling: both must hold.
- **Cost of an operation** is the sum over its pages of the per-page minutes of the Time
  model, each page priced as it is when planning (or when logged, before the op changes it):
  R = the price of the R over its range (the R minutes of its pages with the shared pages
  weighted, see Shared pages: half time), M = sum of the M minutes (ND 60, F3 30 by default),
  L = R. There are no flat per-page minutes any more. In a plan with several ops, a later op
  is priced on the Q after the earlier ones.
- Priority order is configuration. Default: recover (F3, or restart when no F3 page exists),
  expand, R on the working set, C maintenance. M work never takes minutes that mandatory R still needs.
- The user may log anything the engine accepts; planning constraints apply to proposals only.
- **Merged ch.** A successful R on a merged ch must cover all its owned pages (see Merged ch), so
  proposals must never start or end an R range inside them. `PlanningFacts.mergedCh` /
  `mergedRuns` (from `MergedSpans`, owned page spans) carry them. The rule-based planner and both
  simulation policies (`ReferencePolicy`, `RuleBasedSimulationPolicy`) treat a merged ch as one
  block: when picking pages (focus set `activeR` / `parkedR`, `cDue`) it is chosen or left out as a
  whole at its op price (shared pages weighted), and when a range is cut to fit minutes the cut moves
  back to just before the ch's first owned page (nothing left = no range). A block that does not
  fit the minutes left (the ceiling rule is kept) is left out whole, never split; the rule-based
  planner names it in its rationale. Expansion M is unaffected. A proposal that splits a merged
  ch is rejected by the engine; the repair line fed back to the AI names the ch and the owned
  pages ("R must cover all of ch 12, pages 97-106"), the user's own rejection is unchanged.

## Time model

Minutes a user needs per page: settings plus pure functions in
`lib/domain/models/time_model.dart` (`TimeModel`), held by the planning configuration
(`PlanningConfig.time`, default `TimeModel()`, user-settable). It is the only source of
per-page minutes: the planning facts (daily R load, capacity gate, mandatory minutes and the
ceiling), the rule-based planner, the plan validator, the snapshot and prompt, both simulation
policies and the minutes of a logged op all use it. L is priced as R. The daily loads and the
capacity gate also apply the shared-page weight (see Shared pages: half time).

| setting | default | meaning |
|---|---|---|
| `mMinutesNd` | 60 | M on an ND page, per page |
| `mMinutesF3` | 30 | M on an F3 page, per page |
| `rStartMinutes` | 20 | R on a non-prime page in D1 with 0 progress |
| `primeStartFactor` | 0.5 | a prime page starts at `rStartMinutes x factor` (10) |
| `rD3CapMinutes` | 5 | R on D3 (and where the D1/D2 curve ends) |
| `rCCapMinutes` | 4 | R on C. Always a cap, no mode |
| `curveSteepness` k | 3.0 | steepness of the D1/D2 curve |
| `d3Mode` | `cap` | `cap`: D3 costs `rD3CapMinutes`. `cont`: `rD3CapMinutes` while units done in D3 < `d3HoldUnits`, then `rCCapMinutes` |
| `d3HoldUnits` | 2 | used only when `d3Mode` is `cont` |
| `sharedPageShare` | 0.5 for each shared page | for each of the 26 shared pages, the share of its R minutes taken by the earlier ch (see Shared pages: half time). Used by the daily loads, the capacity gate and the op prices (planning facts, validator, rule-based planner, logged op minutes, snapshot group minutes, s hint, prompt text, `ReferencePolicy`) |

Sanity: `rStart >= rD3Cap >= rCCap > 0`, `k > 0`, `0 < primeStartFactor <= 1`,
`d3HoldUnits >= 0`, every `sharedPageShare` key is a shared page of the ch table and every value
is from 0 to 1.

**M** per page: ND -> `mMinutesNd`, F3 -> `mMinutesF3`. Any other state cannot be M'd, so it
costs 0.

**R** per page, from state, progress units in the current level (units done before this R) and
the prime flag:

- D1, D2: `minutes = rD3Cap + (start - rD3Cap) * f(t)`, with
  `f(t) = (e^(-k*t) - e^(-k)) / (1 - e^(-k))`, so f(0) = 1 and f(1) = 0. `start = rStartMinutes`
  (times `primeStartFactor` if prime, never below `rD3Cap`). `t = p / L`, where
  `L = units(D1) + units(D2)` (14 normal, 8 prime, from the Progression table) and `p` counts
  units done across D1 then D2 (in D2, `p = units(D1) + units done in D2`). It starts at
  `start`, falls fast, then slowly, and reaches `rD3Cap` exactly at the end of D2.
- D3: per `d3Mode` (see the table). C: `rCCapMinutes`.
- F1, F2: the cost of the level the page degraded from, with its kept progress. From C:
  `rCCapMinutes`.
- ND, F3: R is not allowed, so it costs 0.

With the defaults, R#n (the nth successful R on the way up, rounded to 0.1):

- Normal: 20.0 17.0 14.5 12.5 10.9 9.6 8.6 | 7.7 7.1 6.5 6.1 5.7 5.4 5.2, then D3 = 5.0.
- Prime: 10.0 8.4 7.2 6.4 | 5.9 5.5 5.3 5.1, then D3 = 5.0.

(`|` marks the D1/D2 boundary.) The functions never check eligibility (the rules above do);
a total over a set of pages prices each page as it is now.

**First R** of a page that newly enters D (used by the capacity gate): R at D1 with 0 progress
for that page's prime flag (`firstRMinutesOf`; the gate itself uses the weighted `firstRLoadOf`,
see Shared pages: half time).

### Shared pages: half time

There are two kinds of R price, and both use the shared-page weight now. The **LOAD price** is
the steady daily load, page by page (below, Loads and the capacity gate). The **OP price** is
what one R or L over a page range costs in a plan or in a log (below, Op prices). **The op
price is now wired everywhere R is priced**: the planning facts, the validator, the rule-based
planner (and so the rule-based simulation policy), the minutes of a logged op, the AI snapshot
(the group minutes and the s hint), the prompt text and `ReferencePolicy`. The one flat number
left is the snapshot `firstR.nd` / `firstR.f3` hint (full price).

- **The rule.** 26 pages are shared by two neighbouring ch (page 106 is in ch 12 and in ch 13).
  In R, a shared page takes only part of its normal R minutes in each of its two ch, half by
  default. The halving applies to the caps as well (the weight multiplies whatever minutes the
  page costs now). If both ch are done, the two parts add up to one full page. **M is not
  affected**: a page is learned once, at full M time.
- **The setting.** `TimeModel.sharedPageShare`: for each shared page, the share taken by the
  EARLIER ch (the page's owner, page 106 -> ch 12); the later ch takes 1 minus that. Default 0.5
  for every shared page, valid range 0 to 1. The keys can only be the 26 shared pages, taken from
  `ChTable.sharedPages` (never typed in); a missing key means 0.5. `TimeModel.earlierShareOf(page)`
  and `laterShareOf(page)` give the two shares (a `RangeError` for a page that is not shared).
  `copyWith` asserts the sanity rules, as do the accessors and the pricing functions (a `const`
  constructor cannot check a map); `TimeModel.sharedPageShareProblem` tells in advance. No
  settings screen yet; the setting is saved with the other planning settings (see Storage).
- **Price of an R range.** `TimeModel.rRangePrice(range, rMinutes, totalPages:)`. The weighting
  is separate from where the minutes come from: `rMinutes` is any function from a page number to
  its R minutes (the real one is the page's own `rMinutesOf`; a constant is enough to check the
  weights by hand). The range is described with `ChSegments.describe` (its structure is used, not
  re-derived). For each segment, the pages shown for it (the segment's first to last page) are
  added up, each at its own minutes times a weight:
  - the segment ch's shared LAST page (shared with the next ch): the earlier share of that page;
  - the segment ch's shared FIRST page (shared with the previous ch): the later share of that page;
  - every other page: weight 1.

  A page's minutes always come from the page's own state, even when it is read as part of the
  later ch. A ch covered whole counts its shared first page even if the range does not contain
  it (R 107-115 is ch 13, shown 106-115: page 106 counts at its later share). **Not the 604-page
  Q:** there is no sharing, the price is the plain sum of the pages' minutes, weight 1
  everywhere.
- **Page weight for loads.** `TimeModel.loadWeightOf(q, page)`, for steady daily loads that work
  page by page. A page that is not shared: 1. A shared page: its earlier share, plus its later
  share if the later ch has at least one entered owned page (not ND; F3 counts as entered, like
  `ChStatus.enteredOwned`), otherwise 0. So a page whose two ch are both in play counts as one
  full page, and a page whose later ch is still unentered counts only the earlier part. Not the
  604-page Q: always 1.
- **Loads and the capacity gate (wired).** Four pure `TimeModel` methods take the Q (the weight
  reads it): `rLoadOf(q, page)` = `rMinutesOf(page)` x `loadWeightOf(q, page number)`;
  `firstRLoadOf(q, page)` = `firstRMinutesOf(page)` x the same weight; `firstRLoadTotal(q,
  pages)` = the sum of `firstRLoadOf`; `firstRLoadPagesThatFit(q, pages, roomMinutes)` = the same
  one-by-one rule and the same small tolerance as `firstRPagesThatFit` (counting stops at the
  first page that does not fit). The old functions are unchanged. Used here, and only here:
  - the planning facts: the three daily loads (working set, the C load behind the C maintenance,
    the pages already R'd or M'd today) are summed with `rLoadOf`, and the number of expansion
    pages the gate admits per direction uses `firstRLoadPagesThatFit`;
  - the validator's capacity gate (the first R of the pages an M adds) and its "restart fits"
    check use `firstRLoadTotal` / `firstRLoadPagesThatFit`;
  - the rule-based planner: the step that decides how many M pages are admitted, and the room it
    takes off after each M (F3 recovery, restart, expansion).

  **The weight is read on the Q as it is BEFORE the op.** So M on pages 106-107 prices page 106
  at its weight before the M (0.5, ch 13 still untouched), even though page 107 enters ch 13
  with the same M. The room is reduced AFTER the op is applied, when the Q has already changed,
  so the first-R load is computed once before the op and that same number is used for the room
  check and for the room reduction; it is never recomputed with the new Q. A Q that is not the
  604-page Q has weight 1 everywhere, so every result equals the old function. M prices never
  change. In the snapshot `firstR.nd` and `firstR.f3` stay flat (full price): they are the only flat number left.
- **Op prices (wired).** Four pure `TimeModel` methods, all taking the Q as it is BEFORE the op:
  - `rOpPrice(q, range)`: `rRangePrice` with each page's own `rMinutesOf` from the Q and
    `totalPages` = the Q's page count (a shared page uses its own state's minutes in both ch);
  - `opMinutes(q, operation, range)`: M = the sum of the pages' M minutes (as before); R and L =
    `rOpPrice` (L is priced as R);
  - `rPagesPrice(q, pages)`: pages in any order and as any list (for example a unit); sorted, a
    repeated page counted once, compressed into ranges, the `rOpPrice` of each range added up.
    Pricing adjacent pages apart or together gives the same total, because a shared page's later
    share is charged exactly once, where the later ch's first owned page is covered;
  - `opPagesThatFit(q, operation, range, minutes)`: how many leading pages of the range fit. M:
    as `pagesThatFit`. R and L: the largest k so that `rOpPrice` of the first k pages is at most
    `minutes` (same small tolerance), 0 if the first page does not fit. The price never falls
    when a page is added, so a binary search finds k (about ten prices for a 604-page range).

  The old functions are unchanged. Used here, and only here:
  - the planning facts: the packing of units (`MergedSpans.units`: a merged ch, or one page)
    into active and parked R prices each unit with `rPagesPrice`; the minutes of `activeR`,
    `parkedR` and `cDue` are `rPagesPrice`, and the mandatory minutes and the ceiling follow from
    them. The daily loads and the gate stay as in the previous part;
  - the validator: the cost of each op (`opMinutes`) and the "at most N pages of this op fit"
    number (`opPagesThatFit`);
  - the rule-based planner: the cost added in `commit` (`opMinutes`) and the unit cost in the R
    packing (`rPagesPrice`);
  - the daily planning service: the minutes of a logged op (`opMinutes`; L as R; a failed R
    costs the same as a successful one).

  **Every op price is read on the Q as it is when that op is planned or logged**, before the op
  changes it. In a plan with several ops, a later op is priced on the Q after the earlier ones
  (the validator's and the planner's running Q). A range outside the Q never reaches the price
  functions: on the 604-page Q `rRangePrice` throws a `RangeError` for it, so the validator
  rejects it with `outOfBounds` before any price is computed (the same check comes first in the
  daily planning service), and planners only build ranges from real pages. A Q that is not the
  604-page Q has no sharing: every op price equals the plain sum (`totalMinutes`, `pagesThatFit`).
  A single page that starts a ch is priced "from its beginning": R on page 107 alone also
  charges page 106's later share, as R 107-115 does.
- **Examples** (every page 10 minutes, shares 0.5). R 97-106 (ch 12 whole): 95. R 107-115 (ch 13
  whole, shown 106-115): 95. R 97-115: 190. R 97-110 (ch 12 whole, ch 13 from its beginning):
  140. R 106-106 (ch 12, middle): 5. R 100-106: 65. R 12-21 (ch 3, no shared page): 100. With the
  share of page 106 at 0.3: R 97-106 is 93, R 107-115 is 97, R 97-115 is 190.

## ch and s

Reference data (`lib/domain/reference/ch_table.dart`, `ChTable`) plus two read-only functions
built on it: one display function (`lib/domain/reference/ch_segments.dart`, `ChSegments`, see
Showing a range by ch) and the status of each ch and s (`lib/domain/reference/ch_status.dart`,
`ChStatus`, `SStatus`, see ch status). They are pure and read-only, but they are used in several
places:
- `ChSegments`: the text of an R or L range for the user in the day record; its structure is also
  read by `rRangePrice` (the op price, see Shared pages: half time).
- `ChStatus`: the engine's merge rules (`MergeRules`: `mergeReady` at day close, unmerge, the
  partial-R rejection and the Q consistency check, see Merged ch); the planning facts (the
  catch-up groups, see Catch-up groups (AI hint), and `TimeModel.loadWeightOf`, so the daily
  loads, the capacity gate in the facts and the validator, and the admit step of the rule-based
  planner); the AI snapshot's ch and s hint (see The ch and s hint in the AI snapshot).
- `SStatus`: only the AI snapshot's s hint.
- The merged ch blocks (`MergedSpans`, from the owned pages and `Q.mergedCh`): the planning
  facts, the validator message, the rule-based planner and `ReferencePolicy`.

No planner or validator decision depends on the status of a ch except through those: merged ch
as units, the catch-up hint, and the shared-page weight. "ch" and "s" are used exactly as
written; they are never expanded or translated.

- A fixed table splits the 604 pages into 71 **ch**. Each ch has a page range and the list of
  **s** it touches (s numbers run 1 to 114). One s can cover several ch, and one ch can touch
  several s.
- The app still works in pages: M, R and all states are unchanged. A ch is a unit built on top
  of pages.
- **Shared pages.** Neighbouring ch can share a boundary page: the last page of one ch is the
  first page of the next (page 106 is in ch 12 and in ch 13). This is intentional; the table is
  never corrected, merged or shifted. No page belongs to three ch.
- **Owner (internal).** Internally a shared page has one owner, the lower-numbered ch (page 106
  is owned by ch 12), so that later a page has one state-owner. This is bookkeeping only. The
  rule lives in one place (`ChTable.ownerOfPage`) so it can be changed easily.
- **What the user sees.** Always each ch's exact range as in the table, shared pages included
  (ch 13 is shown as p 106-115, even though ch 12 owns page 106). The user knows that
  neighbouring ch share a boundary page. Owned pages are never shown as a ch's range (see
  Showing a range by ch).
- **Lookups** (read-only): all ch, ch by number, exact display range, pages of a ch, the ch of
  a page (one or two), owner and owned pages (internal), the shared pages, the s of a ch, and
  every ch that touches an s.
- **Checked once** (an assert, when the table is first built): ch numbers run 1..71 in order;
  ch 1 starts at page 1 and the last ch ends at the last page; first page <= last page; each
  ch starts on the previous ch's last page (shared) or on the page right after it; every s list
  is non-empty, strictly increasing and never goes backwards from one ch to the next; every s
  from 1 to 114 appears at least once.
- **Merged ch** are part of the rules (see Merged ch). Showing a range by ch, the ch status and
  the AI hint stay read-only.

### Showing a range by ch

Describes one contiguous page range (the pages of an R or L operation) for the USER, by ch.
Pure and read-only, nothing is stored (`ChSegments`). M stays as plain page numbers. The AI
never sees this text: the snapshot, the prompt, the parser and the validator messages stay in
pages (the snapshot's ch and s hint gives page spans next to the ch and s numbers).

- **Segments.** Every page of the range goes to its owner ch (`ChTable.ownerOfPage`); pages
  are grouped by ch, in order. For each group the covered pages are compared with the ch's
  owned pages (`ChTable.ownedPagesOf`):
  - `whole`: all owned pages are covered. Shown: the ch's range exactly as in the table (ch 13
    is 106 - 115, even if the range does not include page 106).
  - `fromBeginning`: the covered pages start at the ch's first owned page and stop before its
    last. Shown: from the ch's first page as in the table to the last covered page.
  - `middle`: anything else. Shown: exactly the covered pages.
- **Structure.** A list of (ch, first page, last page, kind), kept apart from the text so a UI
  can lay it out later (`ChSegments.describe`).
- **Text** (`ChSegments.text`, `ChSegments.textOf`): a list of strings, one per item, " - " with
  spaces between numbers.
  - Consecutive `whole` ch are one item over the union of their table ranges: "ch 12 - 13,
    p 97 - 115". One whole ch: "ch 12, p 97 - 106". A one-page range is "p 1", not "p 1 - 1"
    (so ch 1 alone is "ch 1, p 1").
  - `fromBeginning`: "ch 13, from its beginning (p 106) to p 110"; when it is exactly one page, "ch 15, from its beginning (p 128)" (no "to p").
  - `middle`: "ch 13, p 108 - 110".
  - The strings are fixed English text; a localized UI builds its own from the structure.
- **Examples.** 97-115: "ch 12 - 13, p 97 - 115". 97-110: "ch 12, p 97 - 106" and "ch 13, from its
  beginning (p 106) to p 110". 107-115: "ch 13, p 106 - 115". 106-106: "ch 12, p 106".
  50-76: "ch 7 - 9, p 50 - 76". 1-11: "ch 1 - 2, p 1 - 11". 128-132: "ch 15, from its
  beginning (p 128) to p 132".
- **Outside the table.** Pages outside 1 to 604 cannot be described (`describe` throws a
  `RangeError`; `ChSegments.covers` tells in advance), so callers fall back to plain pages.
- **Where it is used.** The day record export (`DayRecord`): each R and L entry (proposed,
  dropped, logged) keeps its `from` and `to` page numbers and gets a `text` list next to them.
  M entries have none, and neither has any entry of a Q that does not have the table's 604
  pages or whose range lies outside the table. No other place turns an R or L operation into
  text for the user yet (`PlanOp.label`, the violation lines and the AI messages are for the AI
  and stay in pages; the placeholder screen shows no operations).

### ch status (read-only)

The state of each ch and each s, described from the Q's current page states (`ChStatus`,
`SStatus`). Pure functions: everything is computed on demand from the Q and the ch table, nothing
is stored, nothing is added to Q or PageRecord, and it is read by the engine's merge rules
(`mergeReady`, unmerge, consistency check), the catch-up groups, `TimeModel.loadWeightOf` (the
daily loads and the capacity gate) and the AI snapshot's ch and s hint (`SStatus` only by the
hint). The Q is read as it is: the caller settles the day first (`catchUp`).

- **Owned pages only** (`ChTable.ownedPagesOf`). A shared page counts only for the ch that owns
  it (page 106 counts for ch 12, never for ch 13). Internal bookkeeping, not the range shown to
  the user.
- **Levels** (for best, worst and average): ND is not entered and is left out. F3 is 0 (lost).
  D1 is 1, D2 is 2, D3 is 3, C is 4. F1 and F2 count at the level of the state the page degraded
  from (D1 if `degradedFrom` is missing), because R restores it there; they are also reported as
  warning pages.
- **ch** (`ChStatus.of`, `ChStatus.all`), one per ch 1..71:
  - `totalOwned`, `enteredOwned` (owned pages that are not ND; F3 counts as entered) and
    `complete` (`enteredOwned == totalOwned`: no owned page is ND);
  - `countsByState`: owned pages per state (ND, D1, D2, D3, C, F1, F2, F3);
  - `best`, `worst` and `average` level over the entered owned pages, null when nothing is
    entered. **The average is a plain unrounded double**: merging rounds the average
    down itself (see Merged ch);
  - `lagging`: owned pages in D1 or in F3, as contiguous page runs (possibly several);
  - `warning`: owned pages in F1 or F2, as contiguous page runs;
  - `mergeReady`: `complete` and every owned page is in D2, D3 or C (no D1, F1, F2, F3 or ND).
- **s** (`SStatus.of`, `SStatus.all`), one per s 1..114: the ch that touch it (`chOfS`, all of
  them, even when the s starts or ends in the middle of a ch: s 4 touches ch 10 to 13);
  `complete` (every one of those ch is complete); `worst` (the lowest ch `worst`, null if any of
  them has nothing entered); `allAtLeastD3` (`complete` and `worst >= 3`).
- **Not the 604-page Q.** Like `ChSegments`, the functions describe the table's 604 pages: for a
  Q that does not have exactly 604 pages they throw a `RangeError` (`ChStatus.covers(q)` tells in
  advance, so a caller falls back). A ch or s number outside 1..71 or 1..114 throws a
  `RangeError` too, like the `ChTable` lookups.

### The ch and s hint in the AI snapshot

Two small blocks of the AI snapshot (`SnapshotBuilder`) and matching wording in the system
prompt. **Information only, never enforced**: no rule, planner, validator, parser, engine,
violation or simulation policy reads or checks them, nothing is stored, and the AI may ignore
them. The AI still proposes M and R as page ranges and never names a ch; the app turns R ranges
into ch text afterwards (`ChSegments`). Both blocks use `ChStatus` / `SStatus` (so owned pages),
and both are left out for a Q that is not the 604-page Q.

- **`ch`**: `{"complete": [{"ch": "12-13", "pages": "97-115"}, ...]}`. The runs of consecutive
  COMPLETE ch (`ChStatus.complete`). `ch` is the first and last ch number of the run (one number
  for a single ch). `pages` is the span of the run: first OWNED page of its first ch to last
  OWNED page of its last ch. Owned pages tile the Q, so the span is contiguous (ch 12 and 13
  give 97-115; ch 13 alone gives 107-115, because page 106 is owned by ch 12). Omitted when no
  ch is complete, that is when every ch has an ND owned page (a Q with no page entered yet). A Q
  whose D range covers whole ch is not left out: those ch are complete, and when their pages are
  in D1 or F3 they also get `catchUp` entries (the test fresh Q, D1 on 282-322, has ch 30-33
  complete and four catch-up entries). The `ch` block as a whole is written when some ch is
  complete, merged or in catch-up (the last two are always complete).
- **`s`**: `[{"s": 2, "pages": "2-49", "min": 192}, ...]`. The s that touch two or more ch AND
  are `allAtLeastD3` (`SStatus`). Single-ch s are left out, because the ch runs already cover
  them. `pages` is computed like a run's span (over the first and last ch touching the s). `min`
  is the R minutes of one pass over those pages, priced as they are now: the op price of the
  span (`TimeModel.rOpPrice`; L would be the same), so shared pages are weighted (a span that
  covers a ch whole counts that ch's shared first page at its later share). Omitted when empty. At most 20 s can qualify.
- **Group minutes** (`groups[].minutes`, the fine and the coarse grouping): for a group that is
  not F3, the op price of the group's whole page range (first to last page, `TimeModel.rOpPrice`
  on the Q as it is now), not the sum of the pages' R minutes; for an F3 group, the sum of the
  pages' M minutes. The prompt says a page shared by two ch costs only part of its R minutes in
  each (half by default) and that the app prices every op exactly.
- **`expansion.backward.order`** (information for building a backward M; the app still checks
  the exact pages): an ordered list of at most 3 entries, `{"s": 5, "block": "106-115", "nd":
  "108,110-115"}`: the first blocks of the backward s list that still have ND pages, in learning
  order (`STable.backwardBlock` from `main.start` down). `block` is the whole block (the pages
  from the s's first page to the page before the range or before the previous block), `nd` its
  ND pages, both as page range text in the snapshot's usual style. A block without an ND page is
  not listed. Present only for a 604-page Q, only when the backward direction is enabled (so not
  in `forwardOnly`) and only when there is a main range. `forward` has no `order`. The prompt
  says: forward M starts right after main's last page and goes up; backward M follows `order`
  (the FIRST pages of the list, in order, no skipped ND page); one op per run of consecutive
  pages, the run with the earliest list page first, fewer ops is better (example 106-115 then
  77-105: M 106-110 is 5 pages, M 77-115 is 39 pages in one op, M 106-115 + M 77-80 is 14 pages in
  two ops); never M ND pages that are not on the forward start or the backward order except
  `restart`; `ndRoom` is the number of ND pages in that direction's order.
- **`ch.merged`**: the runs of MERGED ch (a subset of the complete ones), same format, owned
  span: `{"ch": "11-12", "pages": "87-106"}`. Omitted when none is merged.
- **Prompt.** `ch`: prefer R ranges that start and end on run boundaries; a not complete ch at
  the edge of the learned area is handled by page. `merged`: the ch of a run are one unit; an R
  that includes a page of a merged ch must include every page of it, so R ranges start and end on
  the listed run boundaries, never inside; a partial R is rejected. `s`: a whole s in one go is good when it fits
  the day without crowding out mandatory R or other due pages; never required, a hint, not a
  rule. The wording for catch-up groups is in the next subsection.

### Backward expansion by s (wired everywhere: engine, validator, facts, rule-based planner, ReferencePolicy, AI snapshot and prompt text)

The exact first and last page of every one of the 114 s are kept in a const table
(`lib/domain/reference/s_table.dart`, `STable`: `count`, `firstPageOf`, `lastPageOf`). Two or
more s can start on the same page, and an s often ends on the page where the next one starts
(real data). **These s pages are used ONLY to choose which pages a backward expansion takes.**
The old ch lists (`ChTable`, the s of each ch) are separate and unchanged: the s hint and the
catch-up groups keep using them. They differ from the exact s pages in 29 ch on purpose and
are only an AI hint.

The rule: backward expansion works s by s. It does not take the pages next to the main range;
it takes the latest s that starts before the range and learns it FORWARD from its first page up
to the page before the range, so that it joins the range; then the next earlier s. A page where
one s ends and the next begins goes with the later s. Pure functions:

- `highestStartingBefore(page)`: the highest s whose first page is below `page`; null for page 1.
- `backwardBlock(rangeStart)`: that s and its pages, from its first page to `rangeStart - 1`;
  null for `rangeStart` 1.
- `backwardCandidates(q, rangeStart, maxPages)`: the ND pages to learn, in learning order, at
  most `maxPages`. Start at `rangeStart`; while the list is not full and the start is at least 2,
  take `backwardBlock(start)`: its ND pages in page order go on the list (F3 and every other
  state are skipped; F3 has its own recovery rule); a block without ND pages is passed over; if
  the list is full before all ND pages of the block are in, stop; otherwise the start becomes
  the block's first page. Inside a block the pages go up, the blocks go down. Empty for a Q that
  is not 604 pages or when `maxPages <= 0`.

An s outside 1 to 114 or a page outside 1 to 604 throws a `RangeError`.

**Wired now**, in the RULES side:
- `ExpansionRules.directionOf` takes the Q before the op. Backward on the 604-page Q: every page
  of the M is ND and its page SET equals the SET of the first k entries of
  `backwardCandidates(q, main.start, k)`. A range of whole blocks in a row is accepted; a range
  that does not start at the first candidate page, or leaves a gap, is not (null). Forward is
  unchanged. A Q that is not 604 pages keeps the old backward rule.
- The engine counts an expansion (and records its event) only when `directionOf` gives a
  direction; any other M stays legal and is not counted. The validator calls the same function on
  the running Q (before the op) and gives `notAdjacentToMain` on null; its message says that a
  forward M must start at the page after `main.end`, that a backward M must start at the first
  page of the backward list (with that block's s and pages) and follow the list in order, or that
  no backward page is left.
- Facts: the backward `ndRoom` is the number of pages in `backwardCandidates(q, main.start,
  totalPages)` (0 when the main range starts at page 1); the backward admissible pages (the
  capacity gate, `firstRLoadPagesThatFit`) are computed over that list in its order, not over the
  pages nearest to the range. Forward is unchanged. The main range does not change while a block
  grows.

**Planners.** On the 604-page Q the rule-based planner and `ReferencePolicy` take the backward
pages of an expansion from the backward list, in its order (the planner through
`ExpansionFacts.backwardPages`, `ReferencePolicy` through `STable.backwardCandidates`). How many
pages (n) is decided as before (target, the 3-in-a-row rule, the direction mode, the capacity gate
and the M minutes); the first n entries of the list are taken (pages already taken earlier in the
same plan are no longer ND, so no page is taken twice). They are taken as a SET of pages, sorted and cut
into runs of consecutive page numbers, one M op per run, the run with the earliest list entry
first (usually one op; two or more only when the pages are not consecutive, for example at a
block that is only partly learned, or around pages that are not ND); each op is valid on the Q after the ones
before it (after the first block the main range has grown). Forward is unchanged. A Q that is not
604 pages keeps the old backward pages (the nearest ND pages going down from `main.start - 1`,
one range). Every run is one expansion event, so several runs in one plan count several times
in the 3-in-a-row rule.

**AI snapshot and prompt.** In the `expansion` block, `backward` gets an `order` list (see The ch
and s hint in the AI snapshot, `expansion.backward.order`), and the prompt text explains how a
forward and a backward M must be built.

### Catch-up groups (AI hint)

A **catch-up ch** is a complete ch that cannot merge yet because some of its owned pages are in
D1 or F3. Its lagging pages (even when they are not next to each other) form a catch-up group.
The wish: lift them to D2 so the ch can merge, and keep giving R to the ch's other pages so none
falls back to D1. **Information only, never enforced**: no rule, planner, validator, parser,
engine, violation or simulation policy reads or checks it, nothing is stored, and the AI may
ignore it. The rule-based planner and both simulation policies are unchanged (they already
recover F3 first and give R to the working set). Code: `CatchUpGroups`
(`lib/domain/reference/catch_up_groups.dart`), computed in one place by
`PlanningFacts.compute` (`PlanningFacts.catchUp`) and only formatted by `SnapshotBuilder`.

- **Which ch.** `ChStatus.complete` (no owned page is ND), not in `Q.mergedCh`, and at least one
  lagging page (`ChStatus.lagging`: owned pages in D1 or F3). A ch with only F1 or F2 pages and
  no D1 or F3 page is not one: R restores it and it merges by itself afterwards. A ch with an ND
  owned page is not complete, so it is not one either (it is handled by page). Only for the
  604-page Q; any other Q has none. Owned pages only, like `ChStatus`.
- **Facts per ch.**
  - `lag`: the lagging runs as `ChStatus` gives them (possibly several).
  - `d1`, `f3`: how many owned pages are in D1 and in F3.
  - `hold`: how many of the ch's other owned pages there are, i.e. everything not in D1 and not
    in F3 (F1 and F2 pages included).
  - `r`: the number of further successful R days the slowest lagging page still needs to reach
    D2, the maximum over the lagging pages. A D1 page needs the units to leave D1 for its prime
    flag (7 normal, 4 prime, see Progression) minus its progress. An F3 page needs M first, then
    the prime D1 units (4), because an F3 page is always prime; the M day is not counted.
  - `mMin`: the total M minutes of its F3 pages (`TimeModel.mMinutesF3` each, 30 by default);
    absent when there is no F3 page.
- **Order and cut.** Smallest `r` first, then fewest lagging pages (`d1` + `f3`), then lower ch
  number. At most 10 entries; the number of further catch-up ch is `more`.
- **Snapshot.** `catchUp` inside the `ch` block, in the same compact style:
  `{"ch":12,"lag":"101,104","d1":1,"f3":1,"hold":8,"r":5,"mMin":30}`. `lag` writes a single page
  as the page number, a run as `from-to`, several runs separated by commas. The `d1` and `f3`
  keys are left out when zero and `mMin` when there is no F3 page. The whole `catchUp` key is
  omitted when the list is empty, and `more` (inside `ch`) is added only when entries were cut.
  Left out for a Q that is not the 604-page Q, like the rest of the `ch` block. A ch that has
  just been started (all its pages in D1, for example inside a fresh main D range) is a catch-up
  ch too, with `hold` 0.
- **Prompt.** `catchUp` lists complete ch that cannot merge yet because some pages are in D1 or
  F3 (`lag`); `hold` is how many of their other pages are fine. Priority hint: lift the lagging
  pages to D2 so the ch can merge; an F3 page needs M first (`mMin`), then R. Keep giving R to
  the ch's other pages so none falls back to D1. The lagging pages can be proposed as separate R
  ranges. A hint, not a rule: the usual priorities, the time ceiling and the capacity gate stay
  as they are.

## Merged ch

A ch that is `mergeReady` (`ChStatus.mergeReady`: every OWNED page in D2, D3 or C) becomes ONE
UNIT with one shared state, maintained together. The page records stay: a merged ch is a set of
identical page records plus a flag, `Q.mergedCh` (an immutable set of ch numbers, empty by
default, copied with the Q). Only the 604-page Q of the ch table can merge; for any other size
nothing ever merges. Owned pages are used everywhere (a shared boundary page belongs to the
lower-numbered ch), exactly as in `ChStatus` and `ChSegments`. Display is unchanged: the user
always sees the exact table ranges. Code: `lib/domain/rules/merge_rules.dart` (`MergeRules`).
Planning knows about merged ch (see Planning, merged ch); the costs (`TimeModel`) do not change.
Shared-page half time applies to the daily loads, the capacity gate and the op prices
everywhere R is priced, including the snapshot group minutes, the s hint, the prompt text and
`ReferencePolicy` (see Shared pages: half time). Catch-up groups are an AI hint only (see Catch-up groups (AI
hint)).

- **When a ch merges.** Automatically, only at day close: in `advanceToDay` (so also through
  `catchUp`), after that day's degradation, first unmerge, then merge. A ch that is not merged
  and is `mergeReady` merges. Nothing else triggers it (no M, R or L does).
- **Shared state.** Computed over the ch's owned pages, then set on every one of them:
  - *Level*: the floor of the average level, D2 = 2, D3 = 3, C = 4 (so at least D2). Rounding
    down is deliberate: the unit must not look stronger than its pages on average. A page above
    the level is demoted and loses its extra; a page below it is lifted.
  - *Progress units*: the lowest progress among the owned pages already in that level; 0 when no
    page is in it.
  - *Prime*: the unit is prime only if EVERY owned page is prime. Prime is `cEntries > 0`, so a
    non-prime unit sets `cEntries` to 0 on every page (the only counter changed, because it is
    what expresses the flag). A prime unit keeps each page's own counters.
  - *Clock*: the oldest. The degradation anchor is the earliest anchor of the pages (stored as
    `clockStart`, with `lastM` set to the earliest so nothing is later), and the last successful R
    is the earliest one (none when any page never had one). Nobody's staleness is hidden.
  - *L marker*: a last-L day only if EVERY owned page has one, and then the oldest of them;
    otherwise none.
  - Other counters and history keep each page's own values. `degradedFrom` is empty (all pages
    are in D or C when merging). A page whose state changes gets `stateSince` = the merge day.
  - The pages whose state changed are recorded as transitions with the cause `merge`, like
    every other state change (the day record shows it).
- **All or nothing.** A SUCCESSFUL R or L whose range includes any owned page of a merged ch must
  include ALL owned pages of that ch, otherwise it is rejected with
  `RuleViolationReason.mergedChPartial`, which names the ch (`RuleViolation.ch`). The range is
  judged by owned pages like `ChSegments`: 107-115 covers ch 13 although ch 13 is shown as
  106-115, and 97-115 covers ch 12 and 13, merged or not. An UNSUCCESSFUL R or L is accepted as
  before. M needs no rule: the pages of a merged ch are in D, C, F1 or F2, so M is not allowed.
- **Same page rules.** All owned pages of a merged ch have identical records and only whole-ch
  operations happen, so they stay identical and the page rules (progression, degradation,
  restore from F1/F2) apply unchanged. They are not duplicated for units. `Q.checkInvariants`
  checks that the owned pages of a merged ch stay identical.
- **Unmerge.** At day close, before merging, a merged ch stops being merged when its owned pages
  are ND or F3 (the unit has fallen). The page records stay exactly as they are, and it can merge
  again later by the normal rule. A merged ch stays merged in D1, D2, D3, C, F1 and F2.
- **L on a merged ch** is one marker for the whole ch (it follows from all or nothing) and is
  display only, like any L marker.

## Storage

What is saved, in the app documents directory (code: `lib/planning/data/`, pure Dart except the file store):

- **`state.json`**: the latest Q (every page field, the D ranges with their ids and which one is main, the expansion tracker, `nextRangeId`, `evaluatedThrough`, the transition and operation history, `mergedCh`) plus, if a day is in progress, its session (day, `startQ`, `currentQ`, base budget, extra minutes, logged ops). One file, one write, so the Q and the session can never disagree. The session's `currentQ` is the file's `q`.
- **`settings.json`**: `PlanningConfig` (priority order and `protectMandatoryWork`, the time model with `sharedPageShare`, workload, expansion policy, `maintainCLeadDays`, `maxSnapshotGroups`), `PlannerConstraints` (every field) and the daily base budget (default 120 minutes). Theme and language (`AppSettings`) and the API key are NOT here; they are stored as before.
- **`days/`**: one day record per (Q, day), as before (`JsonDirDayRecordStore`).
- **`notes.json`**: the notes (see Notes), a file of their own next to the others, written the same way (atomic, bad file moved aside to `notes.json.bad-<timestamp>` and never overwritten). It is not inside `state.json`, so a restore of the Q does not touch it. On the web it is the preferences key `notes_v1`. The notes are part of the backup (see Backup).
- Every file has a `schemaVersion`; enums are written by name.

Rules:

- **Proposals are not restored.** A restored session has the day, `startQ`, `currentQ`, the budget, the extra minutes and the logged ops, and no proposals: the user asks for a new plan, which sees the log (no second R on a page that day). The old proposals stay in the day record until the next save of that day replaces it.
- **Start of a day.** If the stored session is for today it is restored. If its day is not today it is dropped; the Q to continue with is the stored `currentQ`, and `startDay` catches it up (`catchUp`: the degradation of every earlier day applies).
- **A Q that loads passes `Q.checkInvariants()`.** If it does not, the load fails with the reason.
- **Failed load: never overwrite.** A file that cannot be read or decoded (not JSON, wrong shape, another schema, a Q that fails its check) is renamed to `<name>.bad-<timestamp>` and the load returns `failed(reason)`. While the load is failed NOTHING is saved (no state, no settings, no `updateSettings`). The only way forward is the explicit `startFresh` action, which replaces what failed (a fresh 604-page Q, or the default settings) and keeps what loaded fine. Nothing stored = a fresh Q (all ND, no D range, fixed id `main`) and the default settings.
- **Atomic writes.** Write `<name>.tmp`, flush, rename over the target. A leftover `.tmp` is never read; the old target is.
- **One save point.** `DailyPlanningService` saves the day record in one place after every state change (`requestPlan`, `log`, `logPlanned`); `state.json` is written from the same place (`onPersisted`), so there is no second save path to forget.
- **Settings.** Missing keys fall back to the defaults (later settings do not break old files); unknown keys are ignored. `settingsProblems(settings)` lists every invalid value with its field name (budget > 0; target >= 0; period >= 1; max in a row >= 1; no duplicate priority class; shared-page shares from 0 to 1 and only for shared pages; plus the sanity rules of `TimeModel`, `WorkloadPolicy` and `PlannerConstraints`). A group with an invalid value loads as the defaults of that group and the problems are reported; the file is not rewritten. **The settings screen must call `settingsProblems` before saving**; `updateSettings` checks again and saves nothing when there are problems. New values reach the engine and the service on their next use.

- **Reading one day record.** `DayRecordStore.read(qId, day)` returns the one record of a (Q, day), or null when that day has none; a record that exists but cannot be read throws a `FormatException` (it is not "none"). Only the notes' day-end check reads it.

### Day record and restarts

The proposals of a day are not restored as objects after a restart, but they are never lost from that day's record. The session's `earlierProposals` holds the `proposals` part of the day record that was last built, as opaque JSON (`state.json` stores it in the session). `DayRecord.fromSession` writes `earlierProposals` first, then the session's own proposals with their `index` shifted by the number of earlier ones, so a day with one restart has proposals 0 (before) and 1 (after). The planned/done matching in the record counts both. `LoggedOp.proposalIndex` is the index in the day record (for a log after a restart it is the own index plus the number of earlier proposals). Logging a planned op (`logPlanned`) and matching a log to a proposal (`asPlanned` / `partial`) use only the current session's own proposals. A day without a restart gives exactly the record it gave before.

## Setup (first run)

A fresh Q (nothing stored) is all ND with no D range, and the planner proposes nothing for it, so the user says which pages are in which state. `QSetup.build` (`lib/domain/rules/q_setup.dart`, pure Dart) turns setup rows into a Q for today, or returns problems that name the row.

- **Row**: from page, to page, state, progress units, days since the last R, was-consolidated-before. Allowed states in domain model: D1, D2, D3, C, F3. Pages in no row are ND.
- **User-facing C constraint**: While `QSetup.build` programmatically accepts state C (for test fixtures and state restores), the user setup interface strictly forbids users from self-claiming state C. The highest selectable level in setup is D3; state C is granted only by the app through verified progression.
- **Prime**: C and F3 pages are prime (they reached C); a D row is prime when was-consolidated-before is on.
- **Progress units**: only for D rows, default 0, and below the units needed to leave the level (normal D1/D2/D3 = 7/7/14, prime 4/4/7), so the largest allowed value is 6/6/13 (normal) and 3/3/6 (prime).
- **Days since the last R**: In the UI wizard, recency defaults to 1 day ago ("Ready to review today", `daysSinceR = 1`), so pages are immediately eligible for review today. Selecting "Already reviewed earlier today" (`daysSinceR = 0`) marks pages as already reviewed today (`lastR = today`, `lastM = today`). `evaluatedThrough` is left empty, so the first day's `catchUp` judges every day through yesterday with the engine's own rules.
- **Problems**: rows that overlap (both rows are named), a page outside 1..604, from greater than to, progress too high (or below 0, or given for a row that is not D), days below 0, and a state that is not allowed (F1, F2, ND).
- **Result**: a Q that passes `Q.checkInvariants()`; the D ranges and the main range are built by the normal rebuild (the largest D range is main, ties by `mainTieBreak`); F3 and ND pages are in no D range.

The setup screen is shown instead of Today when the load result is empty-started. Rather than a flat, technical row table, it uses a guided 6-step **Funnel Wizard**:
1. **Daily Study Time**: Base budget in minutes (default 60 min, quick presets 15, 30, 45, 60, 90).
2. **All Memorized Pages**: Natural multi-range & single-page input (e.g. `1-50, 75, 82-100`), or a skip option for beginners with nothing memorized yet.
3. **Well-practiced pages**: A subset of memorized pages promoted to D3, with recency question (default: ready to review today).
4. **Somewhat familiar pages**: A subset of the remaining pages promoted to D2; pages not selected stay in D1.
5. **Forgotten pages**: Optional input classified as F3.
6. **Review & Confirm**: Visual summary breakdown by state, page counts, validation messages, and JSON import/export.

Finishing setup calls `PlanningController.completeSetup`, writes `settings.json` and `state.json`, switches the load result to loaded, and automatically generates an initial local plan so the user immediately sees today's review schedule. Setup is never shown again on later starts.

## Today screen

The Today tab shows, by the load result: the reason and "Start fresh" (failed; the damaged file was kept, and every other action is disabled), the setup (empty-started) or Today (loaded). Today uses the rule-based planner through the controller; the AI planner is not wired. The app only proposes; the user logs what was done; the log is the truth. Nothing on this screen saves by itself: every change goes through the service, whose one save point writes the day record and `state.json`.

- **Start**: on show, and when the app comes back on a new calendar day, `startToday(Day.fromDateTime(DateTime.now()))`. A stored session of another day is dropped, the stored Q is caught up, and yesterday's log is not shown as today's.
- **Summary**: the date, the budget (base plus extra minutes), the minutes of the latest proposal (the sum of its rows), the minutes done (the sum of the logged ops' minutes) and the minutes left.
- **Make a plan** calls `requestPlan`. **Add time** (15, 30 or 60) calls `requestPlan` with the extra minutes. Both are disabled while a request runs.
- **Proposal rows**: kind (M or R), the ch text, the pages, the minutes (each op priced on the Q before it, as the validator did). The ch text is built from the `ChSegments` structure (whole ch / from its beginning / middle) with localized strings. At-risk pages are shown as a warning and dropped ops in a collapsed "Not included" section with the reason.
- **Done** calls `logPlanned` (successful); a row can be done once. **Not successful** (R only) calls `logPlanned` with `successful: false`; the engine accepts it and it costs the same minutes. **Done partly** (R only) calls `logPlanned` with a sub-range, and the service classifies it as partial.
- **Partial and ownership of shared pages**: the dialog has from / to (prefilled with the whole op) and one chip per ch segment. A chip fills from / to with the pages that ch OWNS inside the op: the earlier ch owns a shared page, so for R 97-115 the chip "ch 12 (p 97 - 106)" fills 97-106 and the chip "ch 13 (p 106 - 115)" fills 107-115, with a note that p 106 belongs to ch 12. If any ch of the op is merged, partial is disabled (a successful R on a merged ch is all or nothing); Done logs the whole op.
- **Log something else** calls `log` with M, R or L, the pages and (R, L) a successful toggle. If the engine rejects it, the dialog stays open with the violation text and the Q is unchanged. An M on ND pages is accepted when there is no D range, which is how a user with nothing learned starts.
- **Nothing to plan & empty proposals**: with no D range, no F3 page and no forgotten page (ND with M history) the plan is empty, and the screen says so instead of showing an error. When a plan is requested but produces no operations (e.g. if the user indicated all pages were already reviewed today and capacity gate prevents new M), the screen clearly explains why (reviews completed today, next session ready tomorrow) rather than presenting an ambiguous empty state.
- **Logged today**: operation, pages with the ch text (R and L), minutes and the kind (planned / partial / custom).
- **Notes for what you reviewed.** Once an R or an L is logged (successful or not), Today shows the open notes of that part under "Notes for what you reviewed", above the logged list, with the same "I remembered" tap (see Notes). Which notes belong to a logged range is `NoteCoverage.covers`. An M shows none. Reading the notes changes nothing in the session, the Q or the plan.

## Page labels

A page is shown with one label, from one function: `LRules.label(page, day, lMonthDays:)` (`lib/domain/rules/l_rules.dart`, pure Dart). D1, D2, D3, C, F1 and F2 are shown in capitals ("D2", "C", "F1") when the page has an ACTIVE L on that day and in lowercase ("d2", "c", "f1") when not. ND and F3 are always "ND" and "F3". "Active" is the engine's own `LRules.isActive`: the page has a last L and fewer than `lMonthDays` days (30 by default) have passed since it (the L day is day 0). The label is for display only; planning and the AI keep the plain domain letters. Every screen that shows a page label uses this function. The pages of a merged ch have identical records, so they show the shared state's label. Counts (in the Overview) count a page in its own state whatever its label.

## Overview

The third tab, read-only (it never changes the Q). The top card has the number of pages per state (ND, D1, D2, D3, C, F1, F2, F3; each page counted once), the number of D ranges, the main range in ch text and the number of merged ch. On a 604-page Q with a main range it also shows where the next forward M starts (the page after the main range, only when that page is ND) and where the next backward M starts (the first page of `STable.backwardCandidates(q, main.start, 1)`, with its s and the block pages); a direction with no room shows nothing. Below it is the list of the 71 ch: the ch number, its table range ("ch 13: p 106 - 115"), one cell per page of that range colored by state (ND grey, D1-D3 blues of rising depth, C green, F1 and F2 amber, F3 red; the same colors in light and dark themes), and a "merged" badge. A shared page is drawn in both of its ch rows with the same color. Tapping a row opens a sheet with each page's label, progress units and the units needed to leave the level (D pages), prime yes/no, the date of the last R and the days since, the date until which an L is active, and the next day the page steps down without an R (`DegradationRules.nextDegradationDeadline`).

## Browse

The fourth tab. Three screens switched at the top: **ps** (every page, 604 by default), **ss** (the 114 s), **ch** (the 71 ch). A row opens its detail screen. Browse never changes the Q; it reads the Q (for states) and the notes (for counts and cards).

- **Where the data comes from.** `browseDataProvider` builds a `BrowseData` (pure Dart, `features/browse/domain/browse_data.dart`) from the latest Q (the Today session's `currentQ`, else the stored Q) and the open-note counts. While the stored data could not be loaded, or the Q is not the 604-page Q, every page reads as ND and no s or ch has a status; the lists and the notes still work.
- **Unit screens (p, s, ch and a part like "s 4 · ch 13").** Every one shows, together: the **info**, the **navigation** and the **notes**.
  - *Page info*: state label (`LRules.label`, capital while an L is active), progress, prime, last R, L active until, next step down. The same facts as the Overview's page sheet.
  - *s / ch / part info*: whether it is complete (no ND page), its worst state (ND when nothing of it is entered), and whether all its pages are at least D3 (complete and worst D3 or better). A **merged ch** also shows its shared state (the state every page of it has, as the page info).
  - *Which pages an s or a ch judges*: the same as `SStatus` / `ChStatus` (a ch its OWNED pages: ch 13 does not count p 106, ch 12 does; an s the ch that touch it). A part is judged on its exact pages.
  - *Navigation*: "More details", only when there is more than one page (see below).
  - *Notes*: the open note cards of the unit, scrollable, with a "+" (see Notes).
- **Two levels of detail.** An s that spans several ch (20 of them) first lists those ch; a ch that touches several s (31 of them) first lists those s. Each row opens a *part*, whose "More details" lists its pages. An s inside one ch, and a ch inside one s, go straight to their pages. The page rows open the page screen.
- **Which ch an s spans, which s a ch touches**: the ch table's own s lists, exactly as written (141 pairs). **Which pages**: the exact ranges, shared pages included (`STable`, `ChTable.displayRange`). The two do not always agree (an s that only ends on the first page of the next ch is not listed in that ch), so a *part* is the intersection of the two exact ranges of a listed pair. Every s is covered exactly by its parts, and every ch by its parts (checked in `test/features/browse`). Example: ch 13 is p 106 - 115; its part of s 4 is p 106 and its part of s 5 is p 106 - 115.
- **Group by**: ps by ch, by s, by **state** or by **open notes**; ss by ch, by state or by open notes; ch by s, by state or by open notes (never by the list's own unit). An item is in every group that holds it: a shared page is in both of its ch (as in the Overview), an s spanning several ch is in each, and the page 604 is in s 112, 113 and 114. Group headers show the exact range (ch, s) or the count (state, notes) and stay pinned while their group is on screen.
  - *By state*: a page by its own state (ND, D1, D2, D3, C, F1, F2, F3); an s or a ch by its worst state (ND, D1, D2, D3, C, F3). A state with no item is left out.
  - *By open notes*: "Has open notes" first, then "No open notes"; an empty group is left out.
- **Rows** show the exact range and the other unit ("p 106" with "ch 12 / ch 13 · s 4 - 5"), and the unit's **open-note count** (nothing for 0). Row texts: `p`, `s` and `ch` are used exactly as written and never translated; only "Browse", "More details", "Group by", "None", "State", "Notes" and the notes and info texts are.
- **Locations**: `/browse` and its children, see `features/browse/presentation/browse_paths.dart`.

## Notes

Short text cards about a page, to remember something. Code: the rules and storage are pure Dart in `lib/notes/` (`models`, `data`, `controller`); the screens are in `features/browse` (the unit screens, the "+" sheet, the archive) and `features/notes` (the view model and the cards). The tests are in `test/notes` and `test/features`.

**Never influence the planner.** The notes are in their own file (`notes.json`), not in the Q, `state.json`, the settings or a day record. No rule, planner, cost, validator, snapshot or AI prompt reads them, and nothing in `lib/domain`, `lib/planning` or `lib/ai` imports them (checked by `test/notes/notes_isolation_test.dart`). The only thing the notes read from the planning side is the day record of a past day (to judge a tap), read-only.

- **A note belongs to a page.** It also has the s and the ch it is filed under; they decide which s, ch and part screens list it (the page screen always lists it). "+" adds a text card; any number of cards, blank text is not a note. Ids are never reused.
- **Which s and ch.** If the page is in one s and one ch there is nothing to choose. If it is shared (p 106 is in s 4 and s 5, and in ch 12 and ch 13), the sheet offers every part that holds the page and the **earlier ch is pre-selected** (p 106: "s 4 · ch 12"). Exception: when "+" is pressed on an s, ch or part screen, the pre-selection is the unit of that screen when it holds the page, so the new card appears on the screen it was added on. The page is fixed on a page screen and typed (within the unit's range) on an s, ch or part screen.
- **"I remembered".** Each open card has the tap. It is accepted silently (no message), one per note per day, and only for an open note. It is first **pending**: today's tap shows as a faint tick and is not in the count.
- **The day-end check** (`NoteBook.settle`, run when the notes are first shown, when a new calendar day starts, and before every tap or new note): a pending tap of a closed day counts only if a **successful R or L** covering the note was logged that day (read from that day's record; an unsuccessful R or L and an M do not count). If it was not, the tap silently disappears. If the day's record cannot be read, nothing is judged and the tap waits for the next try.
- **Covering** (`NoteCoverage.covers`): a logged range covers a note when it contains the note's page, or when it contains every page the note's ch owns (the ch was done whole). So R 107-115, shown as "ch 13, p 106 - 115", covers a note on the shared page 106 that is filed under ch 13, but not one filed under ch 12.
- **The count** ("3/5") is the number of counted closed days. The days need not be consecutive. At **5** the note is resolved (on the day that reached 5), leaves the open list and goes to the archive.
- **The archive.** Quiet, not a screen of the app: a small "Archive (n)" link at the end of a unit screen, shown only when that unit has archived notes, opening a sheet. It is organised per unit and rolls up like the open list: a page its own; an s and a ch their pages' notes; a part the notes filed under both; a merged ch as one unit. Latest resolved first. From it a note can be **restored** (back to open, counting from 0 again) or **deleted** (after a confirmation). **Delete exists only in the archive**; an open card has no delete.
- **Merged ch and covering.** A merged ch is only ever R'd whole, so one R of it covers every note filed under it, on any of its pages and in any of its s (coverage is by pages: the ch is covered whole when the range holds every page the ch owns). A part of a merged ch is still a part: it lists only the notes filed under its own s and ch.
- **Roll-up.** An s lists the notes filed under it (its pages' notes) under a header per page; a ch the same; a part the notes filed under both its s and its ch. A **merged ch** is one unit: its notes are listed together (each card says its page), and the archive the same.
- **Today.** After an R or an L is logged, Today shows that part's open notes (see Today screen).
- **Saving.** A change is kept in memory only after it was saved: when saving fails the notes are unchanged and the screen says "Could not save". All changes run one at a time.

## Backup and Google Drive

Code: `lib/features/backup/` (`data/backup_data.dart`, `services/`, the dialogs in `presentation/widgets/backup_dialogs.dart`). The tests are in `test/features/backup` and `test/features/daily_plan/auto_backup_test.dart`. Setup of the Google side: `docs/DRIVE_SETUP.md`.

**What a backup holds** (`BackupData`, JSON, `version` 2): the planning state (`state.json` text), the planning settings, the app settings, every day record, and the **notes** (`notes.json` text, open and archived, pending taps included). The API keys and the Google sign-in are NOT in it. The same JSON is what "Export Backup" copies and what Google Drive stores.

- **Versions.** Version 1 (before the notes) still restores; it has no `notes`, so a restore of it **leaves the notes of this device as they are**. A backup with a `version` newer than the app's is refused.
- **Read it all first.** `restoreFromJson` reads and checks the whole text (state, settings, notes) before it writes anything: a backup that cannot be read, notes included, changes nothing.
- **A restore replaces** the app settings, planning settings, state, day records and (version 2) the notes, then reloads the planning controller and the screens. **It keeps this device's own Google Drive connection** (`googleDriveConnected`, `googleDriveEmail`, `lastBackupTime`): the sign-in is on the device, not in the backup, so a backup from another device must not make this one look connected.
- **Google Drive is real.** The backup is ONE file, `qrm-backup.json`, in the app's hidden `appDataFolder` (scope `drive.appdata`; the app cannot see the user's other files). Every backup replaces it; the first one creates it in a single multipart request, so the file is never created empty. The text is UTF-8 on the wire and in memory.
- **Sign-in** is Google's OAuth device flow (`GoogleDeviceAuth`): the app shows a code, the user approves it on google.com/device. The refresh token and the e-mail are in the secure store; the access token only in memory (renewed a minute before it ends). A revoked or expired sign-in (`invalid_grant`) is reported as "connect again", never retried silently. The OAuth client comes from `--dart-define` (`DriveConfig`); a build without it says "not set up", it does not pretend.
- **No backup of nothing.** A backup to Drive is refused unless the planning load is `PlanningLoaded` (`DriveNothingToBackUpException`), so a new install in its first-run setup, or one whose data failed to load, can never replace a good backup with an empty state.
- **Automatic backup.** With a frequency other than `manual` and a connected account, a backup is made when the app starts and when it comes back to the front, if the last one is older than the frequency (`daily`: 24 hours, `weekly`: 7 days; none yet: due). It is silent and never throws; a failure leaves it due for the next try.
- **Restore from Drive** asks for confirmation first, and changes nothing when the file is missing, empty or unreadable.
- **What the old version did.** Before this, "Connect" only asked for an e-mail and "Back up" wrote the JSON into the app's own preferences: nothing ever reached Google. That copy is deleted on the first real backup.

## Settings screen

The Settings tab shows theme and language (as before), then every planning setting that `PlanningSettings` holds, in expandable sections: Budget; Expansion (direction mode, target pages, period, max in a row, allow-same-direction, main tie-break, and the expansion policy); Time (every `TimeModel` value except the shared shares); Shared pages (a nested screen, see below); L (L days); Priorities (a reorderable list of the four classes, so a duplicate cannot be made); Planning and workload (C maintenance lead, max snapshot groups, week start, protect mandatory work, the workload policy); and AI planner.

- **Draft and validation.** The planning settings are edited as a draft in the JSON form of `SettingsCodec` (a value like a target of -3 cannot be built into `PlannerConstraints`, but it can be typed, shown with its message and fixed). After every change `settingsJsonProblems` runs and each message is shown under the field it names, by the field path (`constraints.expansionTargetPages`, `time.sharedPageShare[106]`). Save is disabled while there are problems or nothing changed. Save calls `PlanningController.updateSettings`, which checks again and saves nothing on problems.
- **Reset.** Each section has "Reset to defaults" (only that section's fields). "Reset all" asks for confirmation. Both only change the draft; nothing is saved until Save. Leaving with unsaved changes (back) asks to confirm; switching tabs keeps the draft.
- **Apply from the next plan.** The controller rebuilds its engine and service after a save, so new values are used from the next plan. Today's budget stays as it is (it was fixed when the day started); use Add time on Today. The screen says so.
- **Shared pages.** The 26 shared pages come from `ChTable.sharedPages`. Each row shows the page, its two ch ("ch 12 / ch 13"), a slider from 0 to 1 in steps of 0.05 and a number field, the text "ch 12 gets 0.30, ch 13 gets 0.70" (the stored value is the earlier ch's share) and "Reset to 0.5" (which removes the entry; no entry means 0.5).
- **Failed load.** While the stored data could not be loaded, the whole screen is disabled and shows the reason.
- **Values.** The values shown come from the controller, so after a restart the saved values show again.

## AI planner setup

- **What is stored where.** The switch (off by default), the provider (`gemini` or `groq`) and the model per provider are in the app's own settings (`AppSettings`, shared_preferences), not in the planning settings, because they are not planning rules. The API key is in the secure key store only (`SecureApiKeyStore`, one entry per provider): it is not shown again after saving, never put in `AppSettings`, and never logged. "Remove key" deletes it. An empty model means the provider's default.
- **Planner choice.** `aiAwarePlannerFactory` (`lib/ai/ai_runtime.dart`) builds the planner: when the switch is on and a key is saved for the chosen provider, the planner is `AiPlanner` with the rule-based planner as its offline fallback; otherwise it is the rule-based planner. Changing any of these calls `PlanningController.plannerChanged`, so it applies from the next plan. A plan in progress is not affected.
- **Sources.** The Today screen labels a plan "AI planner (Gemini)" (the provider answered and the plan passed the rules), "Offline fallback (the AI planner did not answer)" (the AI was asked and failed, so the rule-based planner answered) or "Offline planner (rules)" (the AI was not asked). The AI never sees or changes the Q; every op it proposes passes the same validator as an offline plan, except that the AI plan's minutes are judged against the silent band (see "Minutes band for AI plans"); an offline plan is always judged strictly.
- **Privacy.** A plan request sends a summary of the Q (page states, no personal text) to the provider. The screen says so.
- **Permission.** Android needs the INTERNET permission in the MAIN manifest (the Flutter template has it only in the debug and profile manifests); it is in `android/app/src/main/AndroidManifest.xml`. The project has no macOS folder, so there is no macOS network client entitlement to set.

## Minutes band for AI plans

The validator is strict about minutes for every caller (the service and the rule-based and offline plans): each op must fit the minutes left under the day ceiling the facts give (the day budget, base plus extra minutes, stretched up to the catch-up stretch only when degraded pages exist, bounded by `maxDailyMinutes`; optional M never uses the stretch). Only the AI planner's validation uses a silent band. The AI is never told about it: the first prompt and the system prompt do not mention it or its factors, and the existing messages keep their strict numbers.

- **Settings.** Two settings in the workload group: `aiLowFactor` (default 0.7, above 0 and at most 1) and `aiHighFactor` (default 1.5, at least 1 and at most 3). A missing key reads as the default. Problems are named `workload.aiLowFactor` and `workload.aiHighFactor`. They are edited in the "AI planner" section of Settings.
- **Upper limit.** For an AI plan the minutes check uses the band ceiling: `aiHighFactor x` the day budget (base plus extra), never more than `maxDailyMinutes` when set, never less than the strict ceiling the facts give. Minutes already spent today are subtracted as before. Under the band both M and R may use minutes up to this ceiling (the optional-M check is not applied). Nothing else is relaxed: the capacity gate, the expansion rules, one R per page per day, the state checks and merged ch stay as they are. Over the band ceiling the violation is `overTimeCeiling` with its usual text, and its numbers (minutes left, the ceiling, "at most k pages") are the STRICT ones; the text never shows the band ceiling.
- **Lower limit.** An AI plan whose total minutes are below `aiLowFactor x reference` is rejected with `underBudget`: "Your plan uses only X min of the Y min available today. Add work that fits within the limits listed." X is the plan's minutes and Y the minutes still available today (day budget minus spent, never below 0). reference is the smaller of Y and the minutes of the offline rule-based plan for the same request (priced by the strict validator). If the reference is 0 the lower limit never rejects. It is only checked when the plan has no other problem, and the existing rule about an empty plan when mandatory work exists is unchanged. The text contains no factor and no offline minutes.
- **Flow.** The AI planner computes the offline plan once per request, before the provider loop, and reuses it as the final fallback. A rejected answer is re-asked once with its violation lines (the `underBudget` line is stored in the attempts like any other), then the next provider, then the offline plan.
- **Today screen.** When the latest proposal's minutes are above the day budget (base plus extra), an amber note says by how many minutes; within the budget there is no note.

