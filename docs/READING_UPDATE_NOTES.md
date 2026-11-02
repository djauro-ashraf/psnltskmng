# Reading update: what to do on first build

The whole reading update was written without a compiler or a device. Nothing here has been run.
Static checks that WERE done: a syntax parse of every `.dart` file (0 errors), a script that
checks each file imports the project symbols it uses, and a script that checks the `en` / `fr`
ARB keys against the generated localizations and every `l10n.xxx` used in `lib/`. The same parse and
import check was run over every test file.

## First build

1. `flutter pub get` (new dependency: `wakelock_plus: ^1.2.8`, for "Keep screen on while reading").
2. `flutter analyze lib` and fix what the compiler finds: expect a few small errors (a wrong
   name, a nullable, an import). The `lib/l10n/` generated files were updated by hand; the ARB
   files are the source, so `flutter gen-l10n` will overwrite them with the same content.
3. `flutter test`. **No test has ever been run**: they were written (and desk-checked against the
   code) without Flutter, exactly like the code. Expect a few red ones on the first run, mostly a
   wrong finder or a layout assumption in the widget tests; the section "Tests" below says which
   are the shaky ones. Use `flutter analyze lib` first if the test noise is in the way.

## Tests

Run from the project root (the divisions test reads `test/fixtures/quran_divisions.json`).

New or rewritten, by what they check:

- **Pure Dart, against the divisions fixture** (an independent source: the juz / hizb / ruku
  file you supplied, not the app's own generated table):
  `test/domain/quran_divisions_test.dart`, `test/quran_data/page_divisions_test.dart`,
  `go_to_input_test.dart`, `words_stream_test.dart`, `words_model_test.dart`,
  `reading_banners_test.dart`, `context_line_test.dart`, `reader_entry_test.dart`,
  `page_locator_test.dart`, `juz_pages_test.dart`, `quran_prefs_test.dart` (the new prefs),
  `test/mushaf/page_ticks_test.dart`, `test/features/browse/reader_request_test.dart`,
  `browse_paths_test.dart` (rewritten), `browse_juz_test.dart` (Group by Juz, juz list and notes).
  `locatorWithContinuations` imitates a real layout pack that repeats an ayah running over a page.
- **Widget tests** (they share `test/support/reader_harness.dart`: a Quran "on the device" made
  from the fixture, a fake Mushaf source, the providers, a stub router, `testReader`, which also
  lets the 90 s surah keep-alive timer run out so no timer is left pending):
  `test/shared/words_rows_test.dart` (ayah card, banners, edges),
  `quran_words_test.dart` (rewritten: `WordsStreamView`),
  `mushaf_side_test.dart` (rewritten: reader page, Mushaf ticks, selection bar, end card, jump),
  `go_to_sheet_test.dart`, `reading_options_sheet_test.dart`, `tafsir_page_test.dart` (against
  `FakeTafsir`, `test/support/fake_tafsir.dart`), `browse_header_test.dart` (Info | Quran switch,
  hint, Continue row, what a tap on a row does, juz tab, Group by Juz).
- **Old tests I judged unchanged** (they open locations through `browseRoute()`, and none refers
  to a deleted file): `browse_data_test.dart`, `browse_screens_test.dart`,
  `browse_runtime_checks_test.dart`, `browse_notes_domain_test.dart`, `merged_ch_test.dart`,
  `test/mushaf/page_side_test.dart`. That is a reading of the code, not a run: if one fails, the
  cause is probably a constructor or a default I changed (`infoOnly`; `BrowseGroups.forPages`
  now holds `juz`; `isScopeScreen` includes `juz/N`).
- **Not tested**: the Overview `J15` dividers (no existing harness for the Overview page), the
  Today "Read this range" button (its rows only exist once a day's proposal exists; the path it
  opens is checked in `browse_paths_test.dart`), the scrub thumb drag, anything about smoothness.
  All of these are in the device checks below.

Shaky tests (the code may be right and the test wrong; fix the test first):

- `quran_words_test.dart`: the one that scrolls and reads the ayah at the top (`_checkTop` walks
  render objects). If it fails and the same thing is wrong on the device, it is a real bug.
- `mushaf_side_test.dart`: anything that checks where something is on the screen (the position pill,
  the end card, the selection bar), the pager and arrows tests, and the end-card flings.
- `tafsir_page_test.dart`: "a long passage is built a paragraph at a time" scrolls inside a
  `SelectionArea`.
- `go_to_sheet_test.dart`: the tab-position checks (a scrollable `TabBar` on a 500 px window) and
  the dismiss tap at the top of the screen.
- Any test that mocks the clipboard (`SystemChannels.platform`) or waits on a timer.

One real bug was found while writing the tests and is fixed in `reader_page.dart`:
after the end card released the Mushaf limit, the position pill and the context line kept showing
the old page (`_releaseMushafLimit` now also updates the page and refreshes the context line).

## Check on a device (these could not be tried)

- **Words seam.** Scroll through at least 10 units on a mid-range phone, flinging across 3 or more
  seams in a row and just after a Go to jump, at 130% and 200% text, light and dark. Watch for a
  hitch, a blank gap, or a jump at a seam. Knobs in `lib/shared/widgets/words_stream_view.dart`:
  `_prefetch = 18`, `_firstForward = 40`, `_firstBackward = 16`, `_step = 24`, and the cache
  extent `height * 1.2`. If it cannot be made smooth, the agreed fallback is: stop at the end of
  the unit with a "Next: Ruku 35" tile and a fade of at most 150 ms. That fallback was NOT built:
  it must be agreed before it is switched to.
- **The scrub thumb** on the right edge: does it win over the list's own vertical drag? (It is a
  28 px strip on top of the list.)
- **The ayah at the top** (context line, saved place, thumb position) is found by walking the
  render objects of the two lists (`_checkTop`). Check it follows the scroll above and below the
  opening ayah, and during a fling.
- Memory after 5 minutes of scrolling (the per-surah data stays 90 s after its last card).
- 130% and 200% text size, V2 print, light and dark, rotation, a long French string in each sheet.
- Back from Info and from Tafsir returns to the exact reading spot; Back from a Today "Read this
  range" button goes to Browse (it uses `context.go`), not to Today.
- Jump highlight (1.5 s, still with "reduce motion") in both views.

## Decisions I made (change them if you disagree)

- The Info | Quran switch is **global** in Browse and saved (`pageSideProvider`). An info screen's
  own toggle opens the reader on top and does not change the saved choice.
- Go to field: `2:255`, `p 42` or just `42` (a page), `j 15`, `hz 29`, `s 2`.
- A **part** opens as Page, limited to its pages. In **V2** the ch unit is not offered (it reads
  as Page) and an s or ch limit uses the planner's V1 page numbers as they are.
- A juz that starts mid-page shares that page with the previous juz; the previous juz owns it for
  status and notes (like a shared page between two ch).
- Meccan / Medinan on the surah banner is **off** (`QuranDivisions.showRevelationPlace`) because
  its source was not confirmed.
- Today did not already open ranges into reading. I added a "Read this range" button on each
  operation row (`today_view.dart`), which opens `/browse/read/range/:from/:to`.
- Tafsir: the screen exists and works against `TafsirContent` (`quran_data/models/tafsir.dart`).
  There is no data side: `tafsirContentProvider` returns `NoTafsirContent`, so no Tafsir button
  shows anywhere until you plug an implementation in `app/dependencies.dart`. Tappable ayah
  references inside a tafsir are a commented TODO in `tafsir_page.dart`.

## Licences to check before the app goes to anyone else

- The juz / hizb / ruku start tables come from the `quran_divisions.json` you supplied
  (`test/fixtures/quran_divisions.json`; `tool/build_quran_divisions.py` turns it into
  `quran_divisions_data.dart`). As you described it, the 558-ruku list is from Quran Foundation
  API data and the boundaries are from an open-source package: the generator does not record
  that, so confirm both licences yourself.
- Every tafsir you add, every translation, and QUL resources (see `RULES.md`, "Terms that go with
  the data").
