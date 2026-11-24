# The reconfiguration: what changed, what was decided, what to check

## First steps on your machine (nothing here could be compiled)

1. `flutter pub get`
2. `flutter analyze` — expect a few errors; the code was written without a Dart compiler (see "How it was checked"). Send the output and they get fixed.
3. `flutter test` — the new tests are in `test/memo/` and `test/planner/`.

## What it is now

See `/RULES.md` (the model) and `docs/ARCHITECTURE.md` (the layout).

## Kept as it was

- The eight statuses and their numbers (progression, tolerated gaps, penalties, fading, dropping, consolidated 8/14/18). Renamed with full words; every number is now editable.
- "Memorise only on what is not learned, review only on what is" (a setting, on by default).
- The reader, Browse lists, tafsir, Ask, Quran data, notes, backup and Drive.

## Removed

- The rule-based planner, the AI planner of before, plan validation, snapshots, the simulator.
- The page-state engine and its page-based records (`Q`, `PageRecord`, setup, restart rules).
- Expansion rules and directions, the time/budget model, catch-up groups, merged ch, shared-page rules, D ranges, the L marker (an L in an old history counts as the R it contains).
- The first-run setup, the Today session (operations, drops, day plans), the planning settings page, the study guide.

## Added

- `lib/memo/` (the core), `lib/planner/` (the small AI planner), the Today / Overview / Settings screens on top of them, `memo.json`.
- Import of your old `state.json` history (once, at first start; the file is not touched) and of old backups.
- Partitions (natural + your own, default = your ch), planner wishes (default text + your own), undo, back-dated logging, "erase the log and start again".

## Decisions made for you

- **Atom = ayah.** Pages/ch/surah/juz are runs of ayahs. A page two ch share is simply in both pieces. Your ch were converted to ayah cuts and verified: all 71 keep the same first and last page as before.
- **Logging clips instead of rejecting.** A range with some parts that do not fit is logged for the parts that do, and you are told how many were left out. (Before, the whole range was refused.)
- **Statuses are judged through yesterday**, like before; the "next step down" day counts the deadline day itself as still ahead.
- **Names:** Not learned, Learning 1/2/3, Consolidated, Fading 1/2, Forgotten (ND, D1-3, C, F1-2, F3). "Memorise" / "Review" instead of M / R on the new screens. They live in `MemoText.status` in `lib/features/memo/presentation/memo_text.dart`: change them there.
- **Page maps:** the standard print is bundled; the 1421 print is read from its downloaded layout once and cached; until then the standard map stands in and Overview says so.
- **Logging is tap-first** (changed after a second look): Today is a worklist (needs attention, next to memorise) with one-tap review, one shared piece sheet used by Today and the Overview, the typed field folded away as a fallback, and one calendar button for back-dated logging. See `/RULES.md`, "Logging and the Today screen".
- **Suggested log from reading** (new): the reader measures time per page (this device only, 30 days, `reading.json`), and Today shows a draft to correct and confirm. Statuses decide Memorise vs Review, time decides whether it counts. See `/RULES.md`, "Suggestions from reading". The reader is touched in three places only (`reader_page.dart`: tracker creation/dispose, lifecycle, a transparent `Listener`).
- **Every number explained** (new): a self-explaining number control (what it is, stepper, original value, what raising/lowering does), presets for the status rules (Original / Relaxed / Strict), a live preview run on the real engine ("reviewed every day: Consolidated on day 28"; "every 2 days: never"), a status sheet on every badge, a *How statuses work* page written from your own numbers, a first-run card on Today. The numbers that were hard-coded are now settings too: length of *Needs attention*, days of reading kept, planner suggestions and history. Two AI texts that were wrong (an "offline planner" that no longer exists, and a privacy note about "your Q") were rewritten in English and French.
- **Words** of the new screens are in `MemoText` (English, French), not in the ARB files, to keep the feature self-contained. Old ARB keys of the removed screens are unused.

## Not done yet (on purpose)

- Browse's ch / surah lists, group sheets and the reader's ch/part units still use the fixed original tables (`ChTable`, `STable`); only their *statuses* come from the new core. Your own partition drives Overview, Today input, the planner and settings. Moving Browse's ch tab to your partition is the next step.
- Notes are still anchored to a page of the standard print and filed by surah/ch (their code did not need to change).

## Tests

Removed, because they tested deleted code or asserted the old state model and could not compile any more:
`test/planning/*`, `test/domain/` (rules engine, progression, degradation, expansion, D ranges, restart, catch-up, simulation, shared pages, page labels), `test/ai/ai_planner_test.dart`, `test/ai/plan_parser_test.dart`, `test/features/daily_plan/*`, `test/features/backup/backup_file_dialogs_test.dart`, `test/features/backup/backup_service_test.dart`, `test/features/browse/{merged_ch,browse_juz,browse_notes_domain,browse_runtime_checks,browse_screens}_test.dart`.
Repaired: the notes tests (now on a `FakeDayLog`), `reader_harness`, `details_blocks_test`, `text_flow_test`, `saved_keys_view_model_test`, `widget_test`.
New: `test/memo/*` and `test/planner/*`.

## How it was checked

No Dart SDK was available. Instead: (1) a script resolves every import and flags project symbols used without being imported, over `lib/`, `test/` and `tool/`; (2) the status engine was ported line by line to Python and run on 24 scenarios (the same ones as in `test/memo/memo_view_test.dart`), all as expected; (3) the default ch partition was validated against the old table. None of that replaces the compiler.
