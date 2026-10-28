# personaltskmng — Architecture

Flutter app **QRM Intelligent Planner**. Rules: `RULES.md`. Domain spec: the QRM build prompt
(Q, M, R, D, ND, C, F are domain terms — never renamed, expanded or translated).

## Stack

| Concern | Package | Notes |
|---|---|---|
| State | `flutter_riverpod` 3.x | `Notifier` / `AsyncNotifier` only, no codegen |
| Routing | `go_router` 17.x | one `StatefulShellRoute.indexedStack`, routes as `Provider<GoRouter>` |
| Settings storage | `shared_preferences` | `SharedPreferencesWithCache`, sync reads |
| i18n | `flutter_localizations` + `intl` (gen-l10n) | `en`, `fr` |
| Lints | `flutter_lints` + a few extras | see `analysis_options.yaml` |

No codegen is required to build. `freezed` / `build_runner` are added only if a
model genuinely needs them.

## Layout

```
lib/
  main.dart            bootstrap → ProviderScope(overrides)
  app/                 app.dart, app_shell.dart, router.dart, dependencies.dart (composition root)
  core/                constants/, errors/ (sealed Failure), theme/
  l10n/                app_en.arb, app_fr.arb (+ generated files)
  shared/              widgets/, extensions/ (generic, feature-agnostic)
  domain/              Stage 1-2: the QRM engine. Pure Dart - no Flutter, no
                        riverpod, no storage import anywhere under here.
    models/            Day, PageState, Operation, PageRange, DRange, Q,
                        PageRecord, StateTransition, OperationRecord,
                        ExpansionTracker, PlannerConstraints, DomainConstants,
                        TimeModel, EngineResult
    rules/              RulesEngine (the only mutator/validator), plus one
                        file per concern: progression, degradation, D-range
                        rebuild (merge/split/main-selection), expansion
                        direction, M eligibility, R eligibility, L (R plus
                        a marker), merged ch (merge_rules.dart)
    simulation/         SimulationPolicy, ReferencePolicy, Simulator - drives
                        the real RulesEngine over many simulated days
    reference/          ch_table.dart: Ch and ChTable, the fixed table that
                        splits the pages into ch (page range + the s each one
                        touches), const data with read-only lookups.
                        ch_segments.dart: ChSegments, describes one page range
                        (an R or L) by ch and builds its text for the user.
                        (Its structure is also read by TimeModel.rRangePrice.)
                        s_table.dart: STable, the exact pages of each s
                        (also `sOfPage`). shared_pages.dart: SharedPages,
                        which pages are in two ch or two s.
                        surah_names.dart: SurahNames / SurahName, the Arabic name, the
                        English name and its meaning of each of the 114 s. Display
                        data only, never read by rules, planners or the AI.
                        ch_status.dart: ChStatus and SStatus, the read-only
                        status of each ch and s derived from a Q (levels,
                        lagging and warning pages, mergeReady), computed on
                        demand, nothing stored.
                        merged_spans.dart: MergedSpans, the read-only view of
                        the merged ch (owned page spans, runs) used by planning.
                        page_input.dart: PageInput and PageUnit, read what the
                        user types for the pages of a log ("12", "p 12", "ch 3",
                        "s 5") and turn it into a page range; one PageUnit per
                        kind of number, new kinds are added there.
                        catch_up_groups.dart: CatchUpGroups, the read-only
                        list of catch-up ch (complete, not merged, with pages
                        in D1 or F3) with their lag, hold, r and mMin; computed
                        once by the planning facts, information only.
                        Read-only. Consumers: the AI snapshot's ch / s hint and
                        catch-up groups, the engine's merged ch (mergeReady)
                        and planning (merged_spans). ch and s are used exactly as written
  features/
    daily_plan/        home screen ("What should I do today?")
    settings/          theme + language + reading direction
      domain/ data/ presentation/ settings.dart (public barrel)
```

Also present:

```
  planning/    pure Dart: config, facts, snapshot, validator, Planner interface,
               RuleBasedPlanner (offline), DailyPlanningService, DayRecord stores,
               data/ (storage codecs + AppStateStore), controller/ (PlanningController)
  ai/          AiPlanner → Gemini / Groq providers, key store, prompt, parser
```

Planned (added stage by stage, not created empty):

```
  features/    q (visualise a Q's ranges), weekly_plan, history (+ daily_plan, settings grow)
```

Q's persistence is now JSON files (see Storage below). If the history grows too
large for one file per write, SQLite (Drift) is the next step: `Q.pages`,
`.transitions` and `.operations` are relational history. Theme, language and reading
direction stay on key-value storage (`AppSettings`, already built).

## The domain layer (Stage 1-2)

`lib/domain` is the deterministic rules engine the build spec (section 22)
requires: a single source of truth for valid states and transitions, with the
AI (Stage 6+) proposing plans that this layer validates, never the reverse.

- **`RulesEngine`** is the only way to mutate a `Q`. `createQ` builds a fresh
  one; `applyM` / `applyR` / `applyL` return `EngineResult<Q>` - either `EngineOk` with
  the updated `Q`, or `EngineRejected` with a `RuleViolation` naming exactly
  which page/range/rule failed. There is no separate validator: applying *is*
  validating, so a rejected AI proposal and a rejected manual edit go through
  the exact same code path.
- **`catchUp`** settles degradation through yesterday; `applyM` / `applyR` / `applyL` call it
  first, so today's R counts as progression. **`advanceToDay`** judges the given
  day as complete and is the end-of-day call (`Simulator` uses it). `Day` has no
  time-of-day, so never call `advanceToDay(today)` before today's R. See `RULES.md`.
- **D ranges are never independently stored** - `Q.dRanges` is rebuilt from
  page states after every mutation (`d_range_rules.dart`). Overlap
  consolidation (section 8) and reconnection after M on forgotten or F3 pages fall
  out automatically from that; the rebuild's only real job is giving the
  resulting runs stable ids and deciding which one is main (section 16's
  larger-fragment-wins rule, with `PlannerConstraints.mainTieBreak` for exact
  ties).
- **Every real state change is logged**, oldest first, on `Q.transitions`
  (state-machine history) and `Q.operations` (M/R attempts, successful or
  not) - `Q.historyFor(page)` answers "why is page 302 D3?" (section 20).
- **`DomainConstants`** holds every progression/degradation number with a doc
  comment citing which spec section it came from, and - where the spec only
  says "approximately" - what was inferred and why (e.g. the D step-down day
  counts, D3's tolerated-cadence math). Change tuning there; nothing
  else should need to change.
- **L** is R plus a marker, logged only by the user (`Operation.l`,
  `RulesEngine.applyL`, `rules/l_rules.dart`). The engine runs the same code as R and
  then sets `PageRecord.lastL`; expiry is derived (`LRules.isActive`, window
  `PlannerConstraints.lMonthDays`), never ticked. `LRules.label` is the one display
  function (capital letters while L-active). Nothing in the rules, the planners, the cost
  or the capacity gate reads the marker, planners and the AI never propose L
  (`PlanValidator` rejects it, the parser has no L), the AI snapshot shows a logged L as
  the R it contains, and no UI shows page state labels yet. See `RULES.md`.
- **Typing pages when logging.** `domain/reference/page_input.dart` (`PageInput.resolve`, `PageUnit`)
  is pure Dart: it reads the From and To texts of the Log session and Done partly dialogs
  (`widgets/dialogs.dart`, both through the shared `_RangeFields`) and returns a `PageRange` or a
  `PageInputError` whose `problem` the UI turns into a localized message
  (`pageInputMessage` in `widgets/plan_texts.dart`). A bare number or `p` is a page, `ch` and `s`
  are units built on the same tables as `ChTable.displayRange` and `STable`; everything below the
  dialog (view model, controller, engine, day record) still only sees pages. The dialog gets the Q's
  page count from `TodayView`, because ch and s exist only for the 604-page Q. See `RULES.md`.
- **Showing a range by ch.** `domain/reference/ch_segments.dart` (`ChSegments`) is a pure,
  read-only function: it gives every page of one range to its owner ch, groups them, and
  returns segments (ch, first page, last page, kind `whole` / `fromBeginning` / `middle`),
  plus the text for them. The structure is kept apart from the text so a UI can lay it out
  later; the text is fixed English, so a localized UI builds from the structure. Its only
  consumer is the day record export: `DayRecord.fromSession` adds a `text` list to each R and L
  entry (planned, dropped, logged) of a 604-page Q, next to the unchanged `from` / `to`; M
  stays as plain pages. Everything the AI sees (snapshot, prompt, parser, validator
  messages, `PlanOp.label`) stays in pages. See `RULES.md`.
- **ch status.** `domain/reference/ch_status.dart` (`ChStatus`, `SStatus`) are pure,
  read-only functions of a Q and the ch table: per ch (owned pages only) the counts per state,
  best, worst and the unrounded average level, the lagging (D1, F3) and warning (F1, F2) page
  runs, `complete` and `mergeReady`; per s, `complete`, `worst` and `allAtLeastD3` over all the
  ch touching it. Computed on demand, nothing stored, no field added to Q or `PageRecord`, and
  it is read by the engine's merge rules (`mergeReady`, unmerge, consistency check), the
  catch-up groups, `TimeModel.loadWeightOf` (the daily loads and the capacity gate: planning
  facts, validator, rule-based planner) and the AI snapshot's hint (`SStatus` only by the hint). The caller settles the day first; a Q
  that is not the 604-page Q throws a `RangeError`, like `ChSegments`. See `RULES.md`.
- **AI ch and s hint.** `SnapshotBuilder` adds two optional blocks to the AI snapshot, from
  `ChStatus` / `SStatus` and `TimeModel`: `ch.complete` (runs of complete ch with their page
  span) and `s` (the s spanning two or more ch with every page at D3 or higher, with page span
  and the minutes of one R pass). Each is omitted when empty, and both when the Q is not the
  604-page Q. The system prompt explains them as a hint. Information only: the parser,
  validator, engine and planners are unchanged and nothing checks s or ch. See `RULES.md`.
- **Catch-up groups (AI hint).** `domain/reference/catch_up_groups.dart` (`CatchUpGroups`)
  is the one place that finds the catch-up ch of a 604-page Q: complete (`ChStatus`), not in
  `Q.mergedCh`, with at least one lagging page (D1 or F3, owned pages only). Per ch it gives
  `lag` (the lagging runs), `d1`, `f3`, `hold` (the other owned pages), `r` (further successful
  R days the slowest lagging page needs to reach D2, from the `DomainConstants` unit counts: an
  F3 page needs M first, then the prime D1 units) and `mMin` (`TimeModel` M cost of its F3
  pages). Ordered by smallest `r`, then fewest lagging pages, then lower ch number; the first
  10 are kept and the rest counted in `more`. `PlanningFacts.compute` calls it once
  (`PlanningFacts.catchUp`); `SnapshotBuilder` only formats it as `ch.catchUp` (+ `ch.more`)
  and the system prompt explains it as a hint. Information only: the engine, merge rules,
  validator, parser, rule-based planner, simulation policies and `TimeModel` are unchanged and
  nothing checks catch-up. See `RULES.md`.
- **Merged ch.** `domain/rules/merge_rules.dart` (`MergeRules`). `Q.mergedCh` is an immutable
  set of ch numbers (empty by default, copied with the Q, always empty unless the Q has the
  604 pages of the ch table); the page records stay, a merged ch is identical records plus the
  flag. `RulesEngine.advanceToDay` (also via `catchUp`) closes a day by applying degradation,
  then `MergeRules.unmerge` (units that fell to ND or F3), then `MergeRules.merge` (every
  `mergeReady` ch: floor of the average level, lowest progress in that level, prime only if all
  pages are, oldest clock, L marker only if all have one), recording `TransitionCause.merge`
  transitions. `RulesEngine` rejects a successful R or L that covers only part of the owned pages
  of a merged ch with `RuleViolationReason.mergedChPartial` (naming the ch). The page rules are
  not duplicated; `Q.checkInvariants` checks that a merged ch stays identical. The
  time model is unchanged. Planning is told about merged ch (see the next entry). See
  `RULES.md`.
- **Shared pages and one R per day.** `domain/reference/shared_pages.dart` (`SharedPages`, pure
  Dart) says which pages are in two or more ch (`ChTable.chOfPage`) or two or more s
  (`STable.sOfPage`): 51 pages, only for the 604-page Q. `RulesEngine.applyR` still allows one
  successful R per page per day, except that a shared page that already earned today's R is
  skipped instead of rejecting the range (a user who goes through ch 12 then ch 13, or s 4 then
  s 5, logs page 106 twice): the page keeps its single unit, no error, and the op is recorded
  as logged. `MergeRules.partialViolation(..., ignoring:)` leaves those untouched pages out of
  the all-or-nothing check. A page that is not shared is still rejected with
  `pageAlreadyRToday`. `PlanValidator` keeps the strict rule for proposals (it checks
  `lastR == day` itself and answers `ViolationKind.alreadyRToday`), so only a logged R can
  repeat a shared page; planners never include such a page. L is unchanged (it already
  accepted an already-R'd page). See `RULES.md`, "Shared pages and one R per day".
- **Shared pages and M.** The same `SharedPages` lets a shared page that is past its entry M take
  ONE repeat M (`MRules.canRepeat` / `applyRepeat`, called by `RulesEngine._applyM`), on any
  later day, until the page is forgotten. The repeat changes only `PageRecord.mRepeated` (cleared
  by the entry M, kept by the ch merge, saved by `QCodec` as `mRepeated`, a missing key meaning
  "not used"); expansion is judged on the entered pages only; `PlanValidator` still refuses
  proposals over a page that is not ND or F3. See `RULES.md`, "Shared pages and M".
- **Planning and merged ch.** `domain/reference/merged_spans.dart` (`MergedSpans`) is the one
  read-only place that turns `Q.mergedCh` and the ch table into merged ch with their OWNED page
  spans, runs of consecutive merged ch, and the units a ranked page list is grouped into.
  `PlanningFacts.mergedCh` / `mergedRuns` expose it; the focus set (`activeR`, `parkedR`) and
  `cDue` treat a merged ch as one block. `RuleBasedPlanner` (and so
  `RuleBasedSimulationPolicy`) takes or leaves a block whole; `ReferencePolicy` moves a cut that
  falls inside a merged ch back before it. The snapshot's `ch` block gets `merged` and the prompt
  says merged ch are one unit. `PlanValidator` turns the engine's `mergedChPartial` into a repair
  line naming the ch and the owned pages (`ViolationKind.mergedChPartial`). The engine, merge
  rules and user-facing text are unchanged. See `RULES.md`.
- **Backward expansion by s (wired everywhere: engine, validator, facts, rule-based planner, ReferencePolicy, AI snapshot and prompt text).** `domain/reference/s_table.dart`
  (`STable`, pure Dart, const data) holds the exact first and last page of the 114 s and the
  pure functions `highestStartingBefore`, `backwardBlock` and `backwardCandidates` (the latest s
  starting before the range is learned forward up to the page before the range, then the next
  earlier s; only ND pages; a shared boundary page goes with the later s). The s pages are used
  only for this. The ch table's s lists are separate and unchanged (s hint, catch-up groups; they
  differ from the exact s pages in 29 ch on purpose, an AI hint only). `ExpansionRules.directionOf`
  now takes the Q before the op: forward is next to `main.end`; backward means the M's page set
  equals the first k entries of `STable.backwardCandidates(q, main.start, k)` (the old rule stays
  for a Q that is not 604 pages). The engine (via `directionOf`, on the Q before the op) counts an
  expansion only then; other M stay legal and are not counted. `PlanValidator` uses the same call
  and its `notAdjacentToMain` message tells where a forward and a backward M must start. In the
  facts, the backward `ndRoom` and the backward admissible pages come from the candidate list
  (`ExpansionFacts.backwardPages`). The main range does not change while a block grows. The
  rule-based planner and `ReferencePolicy` build their backward pages from the same list (the
  first n entries as a set of pages, cut into runs of consecutive page numbers, one M op per run,
  the run with the earliest list entry first, usually one op; a Q that
  is not 604 pages keeps the old pages; forward unchanged). `SnapshotBuilder` adds
  `expansion.backward.order` (the first 3 blocks that still have ND pages: `s`, `block`, `nd`;
  604-page Q, backward enabled, main exists) and the system prompt tells the AI how to build a
  forward and a backward M. See `RULES.md`.
- **Time model.** `domain/models/time_model.dart` (`TimeModel`, settings plus pure
  per-page cost functions) is held by `PlanningConfig.time` and is the only source of
  per-page minutes; it sits in the domain so `ReferencePolicy` can use it too. The planning
  facts (daily R load, per-page capacity gate, mandatory minutes, ceiling), the rule-based
  planner, `PlanValidator`, the snapshot/prompt, both simulation policies and the minutes of
  a logged op price each page by its own state, progress and prime flag. L is priced as R. The
  daily loads, the capacity gate and the op prices of the planning side also apply the
  shared-page weight (next bullet).
- **Shared pages: half time (planning side).** `TimeModel` holds the setting `sharedPageShare`
  (per shared page, the share of its R minutes taken by the earlier ch; default 0.5 for each of
  the 26 pages of `ChTable.sharedPages`, 0 to 1, asserted in `copyWith`) with `earlierShareOf` /
  `laterShareOf`, and pure functions. Two kinds of R price use it. The LOAD price (steady daily
  load, page by page): `loadWeightOf(q, page)` (1 for a page that is not shared, earlier share
  plus later share only when the later ch has an entered owned page) and the load methods
  `rLoadOf`, `firstRLoadOf`, `firstRLoadTotal`, `firstRLoadPagesThatFit`, used by the planning
  facts (the working-set, C and done-today loads, the expansion pages the gate admits), the
  validator's capacity gate and "restart fits" check, and the rule-based planner's admit step
  and room reduction. The weight is read on the Q before the op; validator and planner compute
  the first-R load once before applying the op and reuse that number to reduce the room, never
  recomputing it with the changed Q. The OP price (what one R or L over a range costs):
  `rRangePrice` (weights the pages of a range by their `ChSegments.describe` segments, the
  minutes coming from a function passed in) and the four methods built on it, which take the Q as
  it is before the op: `rOpPrice`, `opMinutes` (M unchanged, L as R), `rPagesPrice` (any list of
  pages, sorted and compressed into ranges) and `opPagesThatFit` (binary search, M as
  `pagesThatFit`). They are used by the planning facts (the packing of units into active and
  parked R, and the minutes of `activeR`, `parkedR` and `cDue`, so the mandatory minutes and the
  ceiling), the validator (the cost of each op and the "at most N pages fit" number, after its
  bounds check, so a range outside the Q never reaches a price), the rule-based planner (the cost
  in `commit` and the unit cost in the R packing) and `DailyPlanningService` (the minutes of a
  logged op, after its bounds check). Each price is read on the Q as it is when the op is planned
  or logged; in a plan, a later op is priced on the Q after the earlier ones. The op
  price is also used by the AI snapshot (the minutes of a group that is not F3 are `rOpPrice` of
  its whole page range, on the Q as it is now; an F3 group stays the sum of its pages' M
  minutes; the s hint minutes are `rOpPrice` of the span), by the prompt text (one added
  sentence on the half price of a shared page) and by `ReferencePolicy` (the R fit uses
  `opPagesThatFit`, the cost of an op uses `opMinutes`, both on the Q given for the day; a
  merged ch is still taken whole or left out); `RuleBasedSimulationPolicy` uses the rule-based
  planner. The one flat number left is the snapshot `firstR.nd` / `firstR.f3` hint. M is never
  affected. No settings UI; the setting is saved with the planning settings (see Storage). See `RULES.md`.
- **Expansion direction mode.** `PlannerConstraints.expansionDirectionMode`
  (`both` by default, `forwardOnly`, `backwardOnly`) sits next to the other
  expansion settings. In `both` the target is split and the 3-in-a-row rule applies to
  planning (`ExpansionRules.isDirectionAllowed`, read by `ExpansionFacts`, `ReferencePolicy` and
  `PlanValidator`; `RulesEngine` only counts expansions in the tracker and never rejects one for
  the streak). In a single-direction mode the enabled
  direction gets the whole target, the alternation rule does not apply, and a
  blocked direction means no expansion (no fallback). It is a planning constraint:
  `ExpansionFacts` (and so the snapshot, both planners and `ReferencePolicy`) and
  `PlanValidator` apply it, the AI prompt states it, and `RulesEngine` does NOT
  reject a manually logged expansion in a disabled direction.
- **`ReferencePolicy` + `Simulator`** exist to prove the engine, not as the
  real planner: a budget-aware policy (recover F3 → R by urgency → expand
  main, respecting the bidirectional (planning) rule; restart when nothing is left in D and no F3 page exists) that `Simulator` runs against the
  real `RulesEngine` for many simulated days. `test/domain/simulation_test.dart`
  reproduces the spec's own example (604 pages, main 282-322, 10/7 expansion)
  and asserts D1→D2→D3→C lands on exactly day 28 under ideal daily care.
- **`test/domain/`** covers section 40's checklist: every state transition,
  D-range merge/split/main-selection (including tie-breaks), the 3-in-a-row
  expansion-direction limit (counted by the engine, enforced for proposals by the validator), missed-R tolerance and penalties, a forgotten or F3 region splitting
  the range and M reconnecting it, and boundary Qs (1 page, 5000 pages).

## Layer rules

- **domain**: pure Dart. No `flutter/*`, riverpod, storage, go_router, intl.
- **data**: implements domain repository interfaces; only place that knows
  storage/JSON. Models never leave `data/`. Wrap storage errors in `StorageFailure`.
- **presentation**: pages, widgets, view models (Notifier/AsyncNotifier), providers.
  Widgets never touch repositories or storage; they watch a view model.
- **Use cases**: only where a real rule exists (validation, cascade). Plain reads go
  view model → repository interface.
- **Errors**: repositories throw `Failure`; view-model actions return `Future<Failure?>`
  (null = success); widgets map `Failure` → text via `shared/extensions/failure_x.dart`.

## LEGO rules (feature isolation)

- A feature imports another feature only through its **barrel** (`<name>.dart`) or
  its **domain** files. Never another feature's `data/`, view models or private widgets.
- Only `app/dependencies.dart` imports concrete `data/` classes. Replacing storage =
  new repository implementation + one line there.
- Each feature's repository provider throws `UnimplementedError` and is overridden
  in the composition root — tests override it with a fake.

## Riverpod conventions

- After every `await` in a notifier, check `ref.mounted` before touching `state`/`ref`.
- Family notifiers take their argument through the constructor.
- In widgets use `ref.watch(provider.select(...))` for narrow rebuilds.
- Forbidden: `StateProvider`, `StateNotifier`, `ChangeNotifierProvider`, `valueOrNull`
  (use `.value`), riverpod codegen.

## Routing

- Paths live in `core/constants/app_routes.dart`. Pages receive ids only and load via
  providers (deep links / web refresh work). Never pass entities through `extra`.
- New tab = one `StatefulShellBranch` in `router.dart` + one destination in `app_shell.dart`.

## Localization (en + fr)

- Every user-visible string goes through `context.l10n`. `app_en.arb` (template) and
  `app_fr.arb` always have exactly the same keys.
- Keys: `<area><Thing>` camelCase. Numbers/dates only via ARB placeholders with a format.
- French ARB: use the typographic apostrophe `’` (a straight `'` is an ICU escape) and
  `\u00a0` before `? ! : ;`.
- **Domain letters (Q M R D ND C F) are never translated** in either language.
- Layouts must survive longer French text: no fixed-height text, allow wrapping.

## Theme

Material 3, light + dark, built once in `core/theme/app_theme.dart`. The color roles are
set by hand (`ColorScheme.fromSeed` only supplies the roles that are not overridden): the
generated tonal-spot surfaces turn pink for the mulberry seed. Spacing, radii and breakpoints
are constants (`AppSpacing`, `AppRadius`, `AppBreakpoints`), no magic numbers in widgets; a bigger
surface gets a bigger radius (cell 3, chip 10, control 12, panel 20, hero 28).

- **Type**: Spectral (serif, bundled in `assets/fonts/`) for titles and the big numbers
  (`titleLarge`, `headline*`, `displaySmall`); IBM Plex Sans for everything else. Both are OFL;
  the licenses are next to the font files. `displaySmall` uses tabular figures.
- **Page states**: `core/theme/page_state_colors.dart` is the `PageStateColors` `ThemeExtension`
  (ND, D1-D3, C, F1-F3, light and dark). Read it with `context.pageStateColors`; never use a raw
  `Colors.*` for a state. In the dark theme "more mature" is brighter, so the D1 < D2 < D3 ramp keeps
  its order. A state must never rely on color alone: pair it with its letters (`StateBadge`) or a
  shape (F cells in the Overview carry a dot).
- **Shared state widgets** (`shared/widgets/page_state_widgets.dart`): `StateBadge`, `PageSpine`
  (every page of the Q as one strip, in the reading direction) and `StateDistributionBar`.
- **Reading direction** (`shared/widgets/text_flow.dart`): `TextFlow` is an `InheritedWidget` that
  `app/app.dart` puts above the navigator from `AppSettings.readingDirection` (right to left by
  default; also the fallback when no `TextFlow` is above, as in a widget test). Widgets that draw
  things in text order read `context.textFlow` / `context.textRunsRightToLeft`: `PageSpine`, the
  Overview's page cells and forward / backward arrows, and Browse's `PageView.reverse` and
  previous / next buttons. A widget never gets its own direction switch, and `Directionality` is
  left alone (the interface language is not the text's direction). Minutes and the other bars do
  not use it.
- The primary (mulberry) is far from every state hue on purpose: the only saturated things on
  screen are the page states. Amber (`tertiaryContainer`) is reserved for cautions.

## Storage

Rules and file contents: `RULES.md`, "Storage". Layout:

- `planning/data/` (pure Dart, no Flutter): `QCodec` (exact Q round trip, runs `Q.checkInvariants()` on load), `SettingsCodec` + `PlanningSettings` + `settingsProblems`, `StoredState` / `StoredSession`, `AppStateCodec` (text <-> object, shared by every store) and the `AppStateStore` interface with `InMemoryAppStateStore`. `FileAppStateStore` is the only file that imports `dart:io` (atomic temp-file + rename writes, bad files renamed to `<name>.bad-<timestamp>`).
- `planning/controller/planning_controller.dart` (pure Dart): `PlanningController` loads settings and state, builds `RulesEngine` and `DailyPlanningService` from the stored settings, exposes `PlanningLoad` (`PlanningLoaded` / `PlanningEmptyStarted` / `PlanningLoadFailed(reason)`), restores or drops the session in `startToday`, and offers `updateSettings` and `startFresh`. It saves nothing while the load is failed.
- Late logging (yesterday, the day before; see `RULES.md`, "Logging on a day that is over"): `planning/day/past_day.dart` (`PastDay`, `PastDays`, `coreOf`, `backfillDays`) is a finished day kept in `StoredState.rewind` (codec: optional `rewind` key in `state.json`, read leniently); `planning/day/backfill.dart` (`Backfill.replay`, pure) runs the history again from a kept day with the new op; `DailyPlanningService.prepareBackfill` builds the new session, kept days and day records, `commitBackfill` saves them; `PlanningController.backfill` ties it to the state and `startToday` keeps the dropped session as a `PastDay`. The Today view model's `logCustom(..., day:)` and `loggableDays()` and the day chips of the Log dialog are the UI.
- Save point: `DailyPlanningService._persist` writes the day record and then calls `onPersisted`; the controller uses it to write `state.json`. Do not add another save path.
- Wiring (same style as settings): `features/daily_plan/presentation/providers/planning_providers.dart` (`planningControllerProvider`, throws until overridden) and `viewmodels/planning_view_model.dart` (`Notifier<PlanningLoad>`). `app/dependencies.dart` builds `FileAppStateStore` and `JsonDirDayRecordStore` (`days/`) in the documents directory (`path_provider` is used only there), loads the controller before the first frame, and overrides the provider. A settings screen must call `settingsProblems` before `updateSettings`.

## Setup and Today screen

Rules: `RULES.md`, "Setup" and "Today screen". Layout:

- `domain/rules/q_setup.dart` (`QSetup`, `SetupRow`, `SetupProblem`): the pure builder of the first Q, next to `RulesEngine.createQ`.
- `PlanningController.completeSetup` stores the built Q and the budget as the new state (empty-started only).
- `features/daily_plan/presentation/`: `pages/daily_plan_page.dart` chooses by the load result (`FailedLoadView`, `SetupView`, `TodayView` in `widgets/`); `SetupView` implements a 6-step progressive Funnel Wizard (Budget → All Memorized → Well-Practiced D3 → Somewhat Familiar D2 → Forgotten F3 → Review & Confirm) with multi-range token parsing (`1-50, 75, 82-100`), user-facing C restriction (max D3), default recency of 1 day ("ready to review today"), and automatic initial local plan generation upon completion; `viewmodels/today_view_model.dart` (`TodayViewModel`, `Notifier<TodayState>`) holds the session and calls the controller's service (`requestPlan`, `log`, `logPlanned`); `widgets/dialogs.dart` has the partial, log and confirm dialogs; `widgets/plan_texts.dart` builds the localized ch text from `ChSegments.describe`. The clock is `todayClockProvider` (overridable in tests).
- `PlanProposal.opMinutes` (from `ValidationResult.opMinutes`) holds the minutes of each op for display; their sum is `PlanProposal.minutes`. Empty proposals are explained with an informative reason card (e.g. pages reviewed earlier today).
- Day record: `TodaySession.earlierProposals` / `StoredSession.earlierProposals` keep the proposals made before a restart in the day's record (see `RULES.md`, "Day record and restarts"). `DailyPlanningService.onPersisted` now receives the session and the record that was just saved.

## Overview, Settings and the AI planner

Rules: `RULES.md`, "Page labels", "Overview", "Settings screen", "AI planner setup". Layout:

- Label: `LRules.label` / `LRules.isActive` (`domain/rules/l_rules.dart`), the one function for page labels.
- `features/overview/` (`OverviewPage`, third tab, route `/overview`): reads the latest Q from the Today session (or the controller's state) and the L days from the controller; watches `settingsRevisionProvider` so it reads again after a settings save. Read-only.
- `features/settings/presentation/`: `pages/settings_page.dart` (appearance, then the planning sections, then the AI section); `widgets/planning_draft.dart` (`PlanningDraft`, the JSON-form draft with `settingsJsonProblems` messages by field path), `planning_fields.dart` (number / switch / choice fields), `planning_priority_and_shared.dart` (priority list, shared-pages screen), `ai_planner_section.dart`. Saving goes through `PlanningViewModel.updateSettings`, which bumps `settingsRevisionProvider`.
- AI: `lib/ai/ai_runtime.dart` has `AiRuntime` (switch, provider, models, which providers have a key; never a key), `aiProviderInfos` and `aiAwarePlannerFactory`. `AiSetupViewModel` saves the switch, provider and model in `AppSettings`, the key in `ApiKeyStore`, updates the `AiRuntime` and calls `PlanningController.plannerChanged`. `app/dependencies.dart` builds `SecureApiKeyStore`, the `AiRuntime` (with which providers already have a key) and the controller with the AI-aware factory; `apiKeyStoreProvider` and `aiRuntimeProvider` are overridden there. Model lists live in `lib/ai/ai_models.dart` (free-plan models per provider, one marked recommended) and reach the screen through `AiProviderInfo.models`. Keys saved under a name are `SavedKeyStore` (`lib/ai/saved_key_store.dart`): one JSON entry in the same `ApiKeyStore`, so device-only and outside the backup; `savedKeyStoreProvider` is derived from `apiKeyStoreProvider` and `SavedKeysViewModel` exposes names only.
- `AppSettings` gained `aiEnabled`, `aiProvider` and `aiModels` (old stored records read with the defaults).
- `AppSettings` gained `readingDirection` (`rightToLeft` by default; a missing or unknown stored value, and backups made before it, read as right to left).
- Backup files: `features/backup/services/backup_files.dart` has the `BackupFiles` interface (`save` with a location chooser, `pick` from storage) and the pure helpers (`backupFileName`, `describeSavedLocation`, `decodeBackupBytes`); `file_picker_backup_files.dart` is the `package:file_picker` implementation (no `dart:io`, so it builds for the web), provided by `backupFilesProvider` (tests override it). `backup_dialogs.dart` holds the export dialog (Save to file / Copy), the import dialog (choose a file or paste, preview, confirm when data exists) and `GoogleDriveDialog` (`restoreOnly` for the first-run screen); the first-run card in `setup_view.dart` opens them.

## Browse (ps, ss, ch)

Rules: `RULES.md`, "Browse". Reference data only: nothing here reads or changes a Q. Layout:

- `features/browse/domain/` (pure Dart): `browse_index.dart` (`BrowseIndex`, `BrowsePart`, `BrowseScope` = `SScope` / `ChScope` / `PartScope`) built once from `ChTable` and `STable`: the ch of an s and the s of a ch (the ch table's own lists), the parts (the pages an s and a ch share), the s and ch on a page. `browse_groups.dart` (`BrowseGroups`, `BrowseGroup`, `BrowseGrouping`): the groups of the three lists, cached.
- `features/browse/presentation/`: `pages/browse_page.dart` is the fourth tab (route `AppRoutes.browse`): a `TabBar` over the three lists. `widgets/grouped_tab.dart` is one list (group-by bar + `BrowseList`, keep-alive so the grouping and scroll position survive a tab switch). `widgets/browse_list.dart` is the efficient list: `SliverFixedExtentList` rows (fixed height, scaled with the text scale), no keep-alive per row, one pinned header per group (`SliverMainAxisGroup`), its own `ScrollController`, flat cards. Looks come from the app theme (`BrowseRowCard`: control-radius card with a tonal count pill; group headers: serif title, hairline only while pinned over rows), so the feature has no colors of its own. `browse_routes.dart` is the route tree (locations in `browse_paths.dart`); detail pages are children of the tab's route and receive ids only (a bad id shows `BrowseNotFoundPage`). `browse_texts.dart` builds the localized labels (`p`, `s`, `ch` are never translated).
- Surah names (see `RULES.md`, "Browse"): `SurahNames` is read by `widgets/surah_labels.dart` (`SurahRowAside`, `SurahHeaderAside`, `SurahTitleCard`, `PageSurahCard`) and by `shared/widgets/surah_arabic_text.dart` (`SurahArabicText`, right to left, `locale: ar`). `BrowseRowCard.aside` and `BrowseSection.aside` take such a widget and shrink it (`FittedBox`) to at most 30% of the row or screen, so a long name or a big text scale never overflows. `ScopeInfoCard` and `PageInfoCard` put the names card above the info panel. The existing title, subtitle and label texts are unchanged; the names are separate widgets.
- The Quran side of a page screen (see `RULES.md`, "Browse"): two small kernels like `lib/notes/`, imported by features and by `shared/`, importing no feature. `lib/mushaf/` is how a page is drawn: `models/` is pure Dart (`MushafPage` reads a page of a layout pack, `MushafFit` is the fitting arithmetic, `MushafEdition` names the two prints and their packs and fonts), `data/mushaf_source.dart` is the interface `MushafSource` (never throws: `MushafPageResult` is ready, not installed, font missing or broken) and `controller/` the providers and the kept side `PageSide` and print `MushafEdition`. `lib/quran_data/` is the downloaded Quran: `models/` is pure Dart (`QuranPack` and `QuranManifest`, `QuranFonts`, the models of the words and translations by s, `FootnoteText` that splits a translation at its footnote markers); `data/` is the file side (`DirectoryPackStorage` in `<app support>/quran`, `PackCodec` the one-line-per-row gzip format, `PackInstaller` with retries, checks and cancel, `QuranRepository` that reads the lines of a page and the words and translations of ayahs, `FileMushafSource` that gives the mushaf its pages and registers fonts); `controller/` holds the providers, the download controller (`QuranDataController`) and the kept choices (`QuranPrefsStore`: view, translation, pack address). `mushaf` never imports `quran_data`; `app/dependencies.dart` is where the downloaded Quran is plugged into `mushafSourceProvider`. The widgets are in `shared/` (`MushafPageView`, `WordsPageView`, `QuranNotice`, `PillToggle`); Browse adds `PageSideToggle`, the `quran` / `showQuran` slots of `UnitScreen` and the Quran side of `page_detail_page.dart`; `features/quran_data/` is only the Quran data screen. `tool/build_quran_packs.py` (with its tests) makes the packs from QUL downloads and `docs/QURAN_DATA.md` describes how they are published.

- The feature imports no other feature. `app/router.dart` adds one `StatefulShellBranch(routes: [browseRoute()])` and `app/app_shell.dart` one destination. One tab with three screens, not three tabs: Material 3 bottom bars are meant for 3 to 5 destinations, and six would crowd the bar and make the rail (used on wide and landscape layouts) taller.

## Minutes band for AI plans (code)

Rules: `RULES.md`, "Minutes band for AI plans". `PlanValidator.validate` takes an optional `MinutesBand` (default null = strict, which every caller except the AI planner uses). `AiPlanner` builds the band from `request.config.workload.aiHighFactor`, computes the offline plan once (`fallback.plan`) before the provider loop, prices it with the strict validator to get the reference, and adds the `ViolationKind.underBudget` issue when an otherwise clean answer is below the floor. `WorkloadPolicy.aiLowFactor` / `aiHighFactor` are in `SettingsCodec` and `settingsProblems`; the fields are in the "AI planner" section of the Settings screen. The Today screen shows `_OverBudgetNote`.

