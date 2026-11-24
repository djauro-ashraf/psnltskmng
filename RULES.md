# Memorisation rules

The Quran is the foundation. Everything else is attached to it, never the other way round.

## The model in four lines

1. **The ayah is the unit.** An ayah has a place, 0 (1:1) to 6235 (114:6). A page, a surah, a juz, a hizb, a ruku and the user's own pieces are only *names for runs of ayahs* (`Span`).
2. **The log is the data.** One line says: on this day, this was done (memorise or review), on this run of ayahs. Nothing else about memorisation is stored.
3. **A partition is a way of cutting the Quran into consecutive pieces**: a list of start ayahs. The natural ones (surah, juz, hizb, ruku, page) are built from the reference data. The user's own (the default is the original *ch*, as 71 pieces) are stored and editable. No memorisation data refers to a partition, so changing one changes nothing but the grouping.
4. **Statuses are worked out, never stored.** The log is replayed in order, per ayah, with the user's rules. Change a rule, a partition or the print: everything is simply worked out again.

Because the unit is the ayah, a page that two pieces share is not a special case: it appears in both, each with its own ayahs. Logging "page 106" touches the end of ch 12 and the start of ch 13 by itself.

## The statuses

Same eight states as before, with names instead of letters (the names live in one place, `MemoText.status`).

| Name | Was | Meaning |
|---|---|---|
| Not learned | ND | Never consolidated: new, or forgotten again |
| Learning 1, 2, 3 | D1, D2, D3 | The learning levels; reviews move an ayah up |
| Consolidated | C | Solid |
| Fading 1, 2 | F1, F2 | Left without review: a warning. One review restores it, to the level it faded from |
| Forgotten | F3 | Consolidated once, then lost: it needs memorising again |

A *unit* (a piece, a page) goes by the weakest status among its learned ayahs; fading counts at the level it faded from.

## What the two operations do

- **Memorise** is taken on *Not learned* and *Forgotten* ayahs. Both start at Learning 1.
- **Review** is taken on Learning 1–3, Consolidated, Fading 1 and Fading 2. On a learning level it earns one unit (at most one review per ayah per day); enough units move the ayah up a level. On Consolidated it refreshes. On Fading it restores.
- A line that does not fit the status of an ayah (a memorise on a learned ayah, a review on one that is not) stays in the log and changes nothing.

### The one rule of logging (can be turned off)

*Keep memorise and review sensible* (Settings, on by default). With it on, the part of a logged range that does not fit is left out and the user is told how much; if nothing fits, nothing is written. With it off, everything is recorded as typed.

## Progression and fading: the numbers

All numbers are the original ones and every one is editable (Settings → Status rules → "Back to the original numbers").

- **Units to leave a learning level**: 7 / 7 / 14 (4 / 4 / 7 once the ayah has been consolidated before: *prime*).
- **Tolerated gap** (days since the last touch that still earn a unit): 1 / 1 / 2 (prime 2 / 2 / 3). A later review earns a unit too, but beyond the forgiven days (1 / 2 / 0) it first costs 2 / 1 / 2 units.
- **Days without review**, from the last memorise, review or step-down: learning 1 fades at 1 and 2 days and drops at 3 (to Not learned; to Forgotten for a prime ayah); learning 2: 2 / 3 / 4; learning 3: 3 / 5 / 6 (prime: 2/3/4, 3/4/5, 4/7/8). A dropped level starts its clock again on the day it dropped.
- **Consolidated**: Fading 1 after 8 days, Fading 2 after 14, Forgotten after 18.

Statuses are judged through *yesterday*: a review today still saves an ayah whose last day is today.

## Logging and the Today screen

Logging is one tap on what you are looking at; typing is the fallback.

- **Needs attention**: the pieces of your default partition where something is forgotten, fading, or falls within a number of days you choose (default 3), most urgent first. The check button logs a *review of the whole piece*; a tap on the row opens the piece.
- **The piece sheet** (from Today and from the Overview): how the piece stands, then **Reviewed** and **Memorised**, each saying how many ayahs it will log (the logging rule is applied before the tap, so nothing surprises). *Only some pages* narrows both to the pages actually done; a page a neighbouring piece shares counts only for the ayahs of this piece.
- **Next to memorise**: the piece holding the first ayah that can be memorised after the last one learned, opened on that page.
- **Type what you did**: `p 12-15`, `ch 3`, `2:255-260`… for anything that is not a whole piece.
- **Another day**: the calendar button logs for a past day and says so until you go back to today.
- Every log gives an **Undo**.
- The ordering ("most urgent first") is only an ordering of what the statuses say; nothing is decided for you.

## Suggestions from reading

The reader can suggest the log, so nothing has to be remembered or looked up afterwards.

- **What is measured:** how long each page is in front of the reader, per day (and how many times it was opened). Only in the reader; only on this device (`reading.json`, kept 30 days, never in the log or in a backup). A page stops counting after *Stop counting after no touch for* (10 minutes by default: reciting while looking at a page does not touch the screen), and while the app is in the background or the screen is off. Turn it all off in Settings → Memorisation, or erase it.
- **What it suggests:** the statuses decide *what* it could have been, the time decides *whether* it counts. Pages passed through in under a minute and a half (90 seconds) in a day count for nothing. Ayahs that were already learned could only have been **reviewed**: suggested as Review. Ayahs that were not learned (or forgotten) could only have been **memorised**, which takes time: suggested as Memorise only when the page was read for 5 minutes or more in the day; below that it was reading. "Learned" is judged as the day began, so memorising during the day does not turn the same reading into a Review suggestion. All three numbers are editable.
- **Left out:** pages the day's log already covers, and pages dismissed or confirmed. Pages that follow each other with the same suggestion are one line.
- **The draft** is on Today, day by day, so yesterday's forgotten log is still there. Each line shows pages, time and how many ayahs it will log. Tap the kind to switch Memorise/Review, tap the line to change its pages, the cross drops it. *Log N lines* writes the day as one group (one Undo, which also brings the suggestions back); *Dismiss* drops the day. Nothing is written until the user confirms.
- Reading in a paper Mushaf, or listening, is not measured: use the piece sheet or the typed log.

## Every number explains itself

No number in the app is shown bare.

- Each number is a control with a title, one line on **what it is**, a stepper (tap the value to type one), the **original value** with a way back to it, and an **info sheet** saying what *raising* it does and what *lowering* it does.
- **Status rules** (Settings → Statuses → Numbers): start from *Original*, *Relaxed* or *Strict*, then adjust. A **preview** at the top says in plain words what the numbers do to a new ayah, by running the real status engine: for instance, with the original numbers a new ayah reviewed every day reaches Consolidated on day 28 (28 reviews), while reviewing it every 2 days never gets it there, because it fades between reviews and rescuing a fading ayah earns no progress. Editing one step of a ladder (a warning, a stronger warning, the fall) moves the others just enough to keep them in order, and says so.
- **Statuses explain themselves**: tap any status badge, or open *How statuses work*: each status says what it means, how an ayah gets there and what happens next, written from your current numbers.
- Every other number is editable and explained the same way: the look-ahead and length of *Needs attention*, the four reading numbers (counts as read / counts as memorising / stop counting after no touch / days kept), and the planner's minutes, most suggestions and days of history.
- While the log is empty, Today shows a short *How this works* card.

## Partitions

- Natural: Surah (`s`), Juz (`j`), Hizb (`hz`), Ruku (`ru`), Page (`p`).
- The user's own: any number, each with a name and a short word. The default, **ch** (71 pieces), reproduces the original ch table exactly (every piece has the same first and last page as before); where two ch used to share a page, the later one now starts at the surah that begins on it.
- Typed anywhere a range is asked: `12`, `p 12-15`, `ch 3`, `ch 3-5`, `s 2`, `j 30`, `2:255`, `2:255-260`, `2:280-3:5`.
- The page map of the standard print (V1) is bundled. The other print (V2) differs on 36 pages: its map is read once from the downloaded layout and kept; until then the standard map stands in and the app says so. Memorisation data never depends on it.

## The planner

There is no rule-based planner. The planner is the user's own AI (key in Settings):

- It is shown the pieces of the default partition with ayahs per status, how soon something falls a step, the numbers that make it fall, and the last ten days of the log.
- It is told what the user wants, in the user's words (*Planner wishes*; there is a default text) and the minutes a day.
- It answers with a short list of memorise / review items. Each is checked against the rule above (the part that does not fit is dropped) and shown on Today; the user logs it with one tap, or ignores it.

Without an AI everything else works.

## Files

- `memo.json`: the log, the settings (the sensible rule, the numbers, the default partition), the user's partitions, the planner wishes.
- `notes.json`: the notes (unchanged; they are still anchored to pages of the standard print).
- The old `state.json` is read once, at first start, to turn its history of successful M and R into log lines. It is never changed or deleted. Old backups (versions 1 and 2) are imported the same way; new backups are version 3.
