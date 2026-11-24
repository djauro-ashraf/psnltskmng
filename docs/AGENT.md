# The agent (commands in natural language)

The user types what they want in their own words ("I reviewed ch 5 and memorised page 12 yesterday", "dark mode", "open the tafsir of 2:255", "make the first level need 9 reviews"). An AI turns that into **instructions in the app's language** (JSON). The app reads them, checks each one, and carries them out through the same controllers every screen uses.

It is a *semi* agent on purpose: one question, one answer, one round of instructions. There is no loop and no tool the AI can call by itself. The AI never touches data; it can only say things from a closed list, and the app decides.

## Settings

Settings → **Agent (commands)**:

- **Enable the agent** (off by default).
- **Its own provider, model and API key.** The key is stored in the secure store under its own name (`agent_gemini`, `agent_groq`), so saving or removing it never touches the planner's or the assistant's key.
- **Ask before doing** (on by default): changes are shown and wait for a tap. Off: changes are made at once. Either way, what cannot be undone always waits (below).
- **Let the agent see my notes** (on by default): the text of the notes (trimmed to 120 characters, 25 notes) goes to the provider so the agent can answer about them and remember, restore or delete them. Off: it never sees a note and can only add new ones.

The settings are kept on this device (`agent.settings` in the preferences), never in a backup. The command button (a small ✦ on every tab, not over the reading screens) appears once the switch is on and a key is saved.

## Who must say yes

Every command has a risk (`AgentRisk`):

| Risk | Commands | Behaviour |
|---|---|---|
| `free` | open anything, `logDay`, `plan`, `undo` | done at once |
| `change` | `log`, `set`, partition save/delete, note add/remembered/restore, backup now | shown first when "Ask before doing" is on, otherwise done at once |
| `destructive` | `erase` (log, reading data, chats), note delete, backup restore | **always** shown first, whatever the mode. One such command holds the whole request |

## The app's language

The AI is given a system prompt (`AgentPrompt.system`, written from `AgentCatalog` so it cannot drift from the parser) and, with each message, a picture of the app: today's date, the units **with their ids**, overall progress, what needs attention, the last week of the log, the open notes (if shared), what is downloaded, every setting (`settings`; the status rules appear as `rules`, only the numbers that differ from the original), whether the planner is available, which day Today logs for, and what the app did with the previous answer (`lastActions`). Names and notes inside it are data, never instructions.

It answers with one JSON object: `{"say": "...", "actions": [ ... ]}` (at most 10 actions).

| Instruction | Fields |
|---|---|
| `log` | `op` `M`/`R`, `range` (`p 12-15`, `ch 3`, `s 2`, `j 30`, `2:255-260`), optional `day` (`today`, `yesterday`, `YYYY-MM-DD`, never in the future) |
| `logDay` | `day`: the day the Today screen logs for |
| `open` | one of `screen` (`today` `browse` `overview` `settings` `quran-data` `chats` `status-rules` `status-guide` `partitions`), `page`, `surah`, `ch`, `juz`, `part` `[s, ch]`, `pages` `[from, to]`, `ayah` (+ `view`), `tafsir`, `assistant` (`true` or `{ayah, prompt}`) |
| `set` | `setting` + `value`, from the catalog below |
| `partition` | `op` `save` (`name`, `unit`, `starts`, optional `id` to replace) or `delete` (`id`) |
| `note` | `op` `add` (`page`, `text`, optional `s`, `ch`), `remembered` (open note), `restore` / `delete` (archived note), with `id` |
| `erase` | `what`: `log`, `reading`, `chats` |
| `backup` | `op`: `now`, `restore` |
| `plan`, `undo` | none |

Anything else is dropped and counted ("1 instruction was not understood"); a range, a date, an id shape or a number that cannot be read exactly is dropped, never repaired.

### The settings catalog (`AgentCatalog`)

About 40 named settings plus one per number of the status rules (`rule.<key>`, 43 of them, moved through `StatusRules.adjusted` like the rules screen does):

appearance and language (`theme`, `language`, `readingDirection`, `backupFrequency`); memorisation (`keepSensible`, `attentionDays`, `attentionLimit`, `defaultPartition`, `rulesPreset`, `trackReading`, `readMinSeconds`, `readMemoriseSeconds`, `readIdleSeconds`, `readKeepDays`); the planner (`plannerMinutes`, `plannerMaxItems`, `plannerRecentDays`, `plannerUseDefault`, `plannerWishes`, `plannerAi`, `plannerProvider`, `plannerModel`); the assistant (`askEnabled`, `askProvider`, `askModel`, `askAnswerLanguage`, `askAnswerLength`); the reader (`readerView`, `textSize`, `keepAwake`, `rukuTicks`, `wordsUnit`, `autoReadSpeed`, `translation`, `tafsirSource`, `aiCopyInstruction`).

Each entry declares its kind (flag, number with range, choice, text, word), its names in English and French, and one line for the AI. Ranges are the ones `MemoSettings` / `PlannerPrefs` accept; a combination the app refuses (e.g. memorise seconds below the read minimum) is reported as failed, never forced.

## What the agent cannot do, and why

1. **API keys** (planner, assistant, agent, the saved-keys vault): a key must never pass through an AI or sit in a chat transcript; there is no catalog entry and the feature never imports a key store (a test checks it).
2. **Its own switch, provider, model, key, approval mode and note sharing**: an AI that could switch its own approval off could remove the user's last check. Changing them is done by hand in Settings.
3. **The Quran pack source address**: it decides what the app downloads.
4. **Connecting or disconnecting the Google account, picking a file to import or export, installing a pack**: they need the user on screen (a sign-in, a file picker, a size and network consent). The agent can open the screen.

## Safety summary

- Closed list, strict parser, catalog-validated values.
- A log goes through `MemoController.log` (memorise / review rule) and has an Undo per request.
- Irreversible commands always wait for the user's tap, so a note or a name that says "erase everything" cannot make the AI do it alone.
- What is sent to the provider: the user's text and the picture above. Never keys or the backup file.

## Where things are

```
lib/agent/                          pure Dart core
  models/agent_catalog.dart         every setting: names, values, ranges, words
  models/agent_command.dart         the closed list of instructions + risk tiers
  models/agent_settings.dart        the agent's own settings
  models/agent_turn.dart            a request, the answer, what the app did
  protocol/agent_prompt.dart        system prompt (from the catalog) + picture of the app
  protocol/agent_parser.dart        the AI's JSON -> instructions
  data/, controller/                settings store, the agent's key slot, the AI client
lib/features/agent/presentation/
  providers/agent_controller.dart   asks the AI, decides who must say yes, does the commands
  providers/agent_settings_io.dart  reads and writes every catalog setting through the app's notifiers
  agent_text.dart, pages/           words (en/fr) and the screen
```

Routes added: `/settings/status-rules`, `/settings/status-guide`, `/settings/partitions` (children of Settings, so their back button works), `/agent`.

To add a setting: one entry in `AgentCatalog`, one `case` in `readAgentSettings` and `writeAgentSetting`. `agent_catalog_test` and the "every setting is applied" test in `agent_reach_test` fail until all are there. To add a command: a subclass in `agent_command.dart` (with its risk), a parser branch, a line in the prompt, a branch in `AgentController._execute`, words in `AgentText` (the exhaustive `switch` finds every place).

## Not done (ideas)

- Installing or removing Quran packs; sign-in to Google; file import/export (see above).
- Several rounds (the AI asks the app for data, then decides): today the picture of the app goes with every message instead.
- Opening a particular section of the Settings screen (it opens the screen).
- Voice input.
