# Architecture

Flutter, Riverpod, go_router. Pure-Dart cores with plain-Dart controllers; the UI only exposes them.

```
lib/
  memo/                 the memorisation core (pure Dart)
    models/             Span, MemoEvent, MemoStatus, StatusRules, MemoSettings,
                        PageMap, Partition, MemoView (the replay), PlannerPrefs, MemoData
    rules/              RangeInput (what the user types), MemoRules (the one logging rule)
    data/               memo.json codec + stores, legacy import, bundled page/ch tables
    controller/         MemoController (load, log, undo, settings, partitions, restore)
  planner/              the small AI planner: snapshot, prompt, parser, service
  ai/                   providers (Gemini, Groq), key stores, chat (also used by Ask)
  domain/               Day, PageRange and the static reference tables (ch, s, divisions)
  notes/                the notes (own store and controller)
  quran_data/, mushaf/  the Quran, its words, the print and the pages
  ask/                  the assistant
  agent/                the command agent core (pure Dart): the app's language
                        (settings catalog, commands, parser, prompt), its own
                        settings and key slot
  features/
    today/              log, the day's lines, the AI plan
    overview/           the whole Quran at a glance, then the pieces of a partition
    browse/             the lists and the reader (statuses come from the memo core)
    memo/               providers (memoProvider, pageMapProvider) and MemoText
    settings/           appearance, memorisation, rules, partitions, planner wishes, AI, agent
    agent/              the command screen and the controller that carries commands out
    backup/             file and Drive backup of settings + memo.json + notes
  app/                  composition root, router, shell
```

## Dependency direction

`Quran (ayahs) <- log <- statuses`. Partitions, pages and the print are *lenses*: they are read when drawing and never written into data.

## Rules of the road

- Save first, then hold in memory (`MemoController._commit`); one writer at a time.
- The log holds facts, never conclusions: no migration is needed when a rule, a partition or the print changes.
- Words of the memorisation screens are in `MemoText` (English and French); those of the agent are in `AgentText`.
- The agent never touches data itself: its AI only produces instructions from a closed list (`docs/AGENT.md`), each is checked by `AgentParser` and carried out through the same controllers as the screens.
