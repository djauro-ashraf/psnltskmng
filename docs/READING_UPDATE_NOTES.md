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
  Downloaded packs are read by `StorageTafsirContent` (`quran_data/data/storage_tafsir_content.dart`)
  via `tafsirContentProvider`. When no tafsir is downloaded, no Tafsir button shows anywhere.
  Tappable ayah references inside a tafsir are a commented TODO in `tafsir_page.dart`.

## Licences to check before the app goes to anyone else

- The juz / hizb / ruku start tables come from the `quran_divisions.json` you supplied
  (`test/fixtures/quran_divisions.json`; `tool/build_quran_divisions.py` turns it into
  `quran_divisions_data.dart`). As you described it, the 558-ruku list is from Quran Foundation
  API data and the boundaries are from an open-source package: the generator does not record
  that, so confirm both licences yourself.
- Every tafsir you add, every translation, and QUL resources (see `RULES.md`, "Terms that go with
  the data").

## Collapsible ayah sections (Words)

Each ayah card of the Words view has three sections, each with a title row that opens or closes
it: **Arabic** (the whole ayah), **Word by word**, **Translation**. The choice is one for the
whole reader: close the translation on one ayah and it is closed on all of them, and it stays
closed next time. The same three switches are chips under **Ayah sections** in the reading options.

Where it lives:

- `lib/quran_data/models/ayah_sections.dart` (new, pure Dart): `AyahSection` and `AyahSections`
  (a small immutable value: which sections are closed; written as `words,translation`).
- `lib/quran_data/controller/quran_prefs.dart`: `QuranPrefKeys.closedSections`,
  `AyahSectionsNotifier`, `ayahSectionsProvider` (all open is the default and keeps nothing).
- `lib/shared/widgets/words_rows.dart`: `AyahCard` gets `sections` and `onToggleSection`; the title
  rows are `_Section` / `_SectionTitle`. A closed section is only its title row.
- `lib/shared/widgets/words_stream_view.dart`: a change makes a new stream, like a new translation
  or text size (cards change height, and rows above the screen would push the reader's place
  out). It is opened on the ayah whose title was tapped, which then sits at the top; a change from
  the reading options keeps the ayah at the top.
- `lib/features/browse/presentation/widgets/reading_options_sheet.dart`: the chips.
- New texts (en, fr; the generated files were updated by hand too): `wordsSectionArabic`,
  `wordsSectionWords` (the Translation title reuses `wordsTranslation`), `readerSections`,
  `readerSectionsHint`.

Tests: new `test/quran_data/ayah_sections_test.dart`; added to `quran_prefs_test.dart`,
`test/shared/words_rows_test.dart` (group "the sections"), `quran_words_test.dart` (group "the
sections of the card"), `reading_options_sheet_test.dart`. One old expectation changed: the sheet
now has the word "Translation" twice (the heading and the chip), so that line says 2. NOT RUN, like
the rest; the shaky ones are the stream tests that tap a title and read where the card ended up
(`getTopLeft(...).dy < 80`).

Check on a device: tap a title in the middle of the screen (the card should jump to the top, the
rest follow, no blank gap); close all three on a long surah and scroll; change a section from the
reading options while scrolled deep into a surah (the ayah at the top should stay); 200% text and a
320 px wide screen (titles stay on one line, the chevron stays visible).

## Page marks in every unit (Words)

Before, the page showed in the stream only when the unit was Page. Now it shows in every unit:
where a page starts (the first ayah that starts on it) the element of that ayah says `p 43`, and an
ayah that runs over a page break says `continues on p 44`.

- A page that starts where a surah, juz or hizb starts is a chip on that banner; where a ruku starts
  it is `Ruku 4 · 10 ayahs · p 6` on the hairline (the ruku hairline never showed the page before,
  also not in Page); where nothing else starts it is a slim `p 43` hairline. Never two elements for
  one place. A ch banner does not repeat the page its label already starts at.
- `lib/quran_data/models/words_stream.dart`: `AyahPageInfo` and `WordsStream.pageInfoOf(ayah, locator)`
  (pure Dart; the page that starts at the ayah, the page it goes on over).
- `lib/quran_data/models/reading_banners.dart`: `ReadingBanners.at(..., pageStart:)`.
- `lib/quran_data/models/words_model.dart`: asks for the page info of every ayah it makes (not in the
  Page unit, whose chunks know it already) in both directions. A layout that cannot be read leaves
  the page marks out, it never fails the stream.
- `lib/shared/widgets/words_rows.dart`: the ruku hairline carries the page; one `_pageLabel` helper.
- No new texts (the numbers and the letter `p` are never translated).

Tests: `reading_banners_test.dart` (group "the page that starts at an ayah, whatever the unit"),
`words_stream_test.dart` (group "where an ayah is on its pages", against all 604 pages of the
fixture), `words_model_test.dart` (group "the page marks, in every unit", forward and backward,
all units, with and without continuations, unreadable and missing layout), `words_rows_test.dart`
(banners), `quran_words_test.dart` (group "the page marks"). NOT RUN, like the rest. The shaky one is
"the marks are above too": it scrolls a long way up and reads a marker from the cache.

Check on a device: scroll in Juz, Ruku and Whole Quran units and look for a `p N` at every page
break; check the first scroll after opening is as smooth as before (each ayah now asks the layout,
which is cached after the first reads); 200% text, 320 px wide.

## Swipe to the next / previous unit (Words)

The ◀ / ▶ arrows of the reading line only show from 480 px, so on a phone there was no way to step
a unit. A swipe sideways over the words now does the same step, on every screen.

- `lib/features/browse/presentation/widgets/unit_swipe.dart` (new): `UnitSwipe`, a `Listener` around
  the stream (raw touches only, it never enters the gesture arena, so scrolling, taps and long
  presses are untouched). `UnitSwipe.read(...)` is the pure decision: at least 56 px across, at
  least twice as far across as up or down, still moving at 200 px/s or more the same way when the
  finger leaves. A vertical scroll, a short or slow drag and a two-finger touch are not swipes.
- The way follows the reading direction like the Mushaf pager: text right to left (default), a swipe
  **to the right** is next; left to right, a swipe to the left.
- `reader_page.dart`: wraps `WordsStreamView` in `UnitSwipe` (off for the Whole Quran unit, where a
  step back would have jumped to the start of the Quran) and calls the same `_stepUnit` as the
  arrows. `_stepUnit` now (1) drops a second step asked while one is being worked out and (2) does
  not step out of a part or a range (`limit.ayahs`), for the arrows too: before, an arrow in Words
  could leave the part the reader came in through.
- No new texts, no new settings.

Tests: `test/features/browse/unit_swipe_test.dart` (the decision, both directions, taps and scroll
untouched, two fingers, cancel, disabled), `mushaf_side_test.dart` (group "a swipe over the words":
a narrow screen with no arrows, left to right, the surah unit, short / slow, Whole Quran, the range
limit for swipe and arrows). NOT RUN, like the rest. The shaky ones are the reader ones that read
the position pill after a `fling` (they rely on the stream reporting its top ayah after it opens).

Check on a device: swipe in Page, Juz and Surah units on a phone and on a tablet; with the Reading
direction setting on right to left and on left to right; make sure a normal vertical scroll never
steps and a long press on a note still selects text.

## Copy, selection, unit edges, Ask AI and auto-read: review and completion

The reading features written from `WORDS_MODE_NEXT_STEPS_ADVICE.md` (copy builder, selection,
unit edges, the assistant with its chats, auto-read) were reviewed and finished. Nothing was run
(analysis and tests are left to the owner of the project).

Words, selection and edges
- `words_model.dart`: after a pass or a release the fence of that direction moves to the unit that
  was entered (before, the next unit's edge never held again).
- `words_stream_view.dart`: a selection stops the auto-read ticks and the unit swipe (`onSelecting`,
  also cleared on dispose); the scroll listener keeps checking the top ayah while auto-read runs;
  the edge tiles use the localized texts; `onAskAi(ayah, focus)` carries the selected words.
- `reader_page.dart`: Ask buttons only when `askAvailableProvider` is true; auto-read stops when the
  reader closes; the pill follows `AutoReadState.active`.

Auto-read
- `auto_read_provider.dart`: `active` (a pause keeps the pill, `stop()` takes it away).
  `auto_read_pill.dart`: close button, localized tooltips.
- `mushaf_reader.dart`: progress line through a `ValueNotifier` (no rebuild of the page every
  tick), a touch on the page restarts the wait.

Assistant
- `ask_settings_store.dart` / `shared_ask_settings_store.dart` (new) and `AskSettingsNotifier`:
  the settings are saved. `ask_settings_section.dart` (new) in Settings: switch, provider, model,
  key, language, length, chat count and size, delete all.
- `ask_providers.dart`: `askAvailableProvider`, `ChatDetailNotifier` (retry, stop that keeps the
  partial answer, delete, rename, attach), `ChatListNotifier.remove / restore / rename` (a swiped
  chat leaves the list in the same frame, as `Dismissible` needs).
- `ask_preset.dart`: `AskFollowUp` enum (the chips are localized, the instruction stays English
  for the model). `ask_markdown.dart` (new): bold, italic, bullets, headings, ayah references.
- `file_chat_store.dart`: an index that is missing or damaged is rebuilt from the chat files.
- `gemini_chat.dart` / `groq_chat.dart`: an idle timeout on the stream, network errors mapped to
  `AiProviderException`, a blocked Gemini answer reported.
- `ask_chat_page.dart` (rewritten), `chats_list_page.dart` (rewritten), `ask_chat_text.dart` (new):
  localized, markdown answers, the thread follows the answer while it streams (and stays put when
  the reader scrolled up), presets only with an ayah attached, Retry for a question without an
  answer, calendar-day labels (Today / Yesterday).
- `ayah_copy_sheet.dart`: Ask AI button (one ayah), a "Copy for AI" menu that looks enabled
  (`MenuAnchor`), notices for missing tafsir.
- Texts: about 30 new keys in `app_en.arb` / `app_fr.arb` and the generated Dart (written by hand to
  match `flutter gen-l10n`; run it once to be sure they are identical).

Tests added: `auto_read_provider_test.dart` (pause / stop), `ask_markdown_test.dart`,
`ask_preset_test.dart`, `file_chat_store_test.dart` (index rebuilt / damaged), `chat_stream_test.dart`,
`ayah_copy_sheet_ask_test.dart`, `chats_list_page_test.dart`. NOT RUN. The shaky ones are the
swipe-to-delete and rename tests of the chats list (they depend on `Dismissible` and the bottom sheet
timing) and the copy sheet ones (they scroll a sheet to reach the buttons).

Check on a device: select words in a card, then *Ask AI*; the chat opens with the ayah and the words
in the box; stream an answer and scroll up while it writes (it must not jump); airplane mode and
Retry; a missing key; delete and Undo in the list; auto-read in Words (pause, resume, pill close,
select text while it runs) and in Mushaf (touch the page, last page); Gate and Locked on a unit
and the one after it.
