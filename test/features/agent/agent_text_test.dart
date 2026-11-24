import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/models/agent_catalog.dart';
import 'package:personaltskmng/agent/models/agent_command.dart';
import 'package:personaltskmng/agent/models/agent_turn.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/agent/presentation/agent_text.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/span.dart';

const Day _today = Day(20000);

LogCommand _log({MemoKind kind = MemoKind.r, Day day = _today}) => LogCommand(
  kind: kind,
  span: const Span(0, 6),
  day: day,
  rangeText: 'ch 5',
);

SetCommand _set(String id, Object value) =>
    SetCommand(AgentCatalog.byId(id)!, value);

void main() {
  final en = AgentText.forLanguage('en');
  final fr = AgentText.forLanguage('fr');

  group('a pending line says what a log will do', () {
    test('English', () {
      expect(
        en.command(_log(), today: _today, willLog: 40, skipped: 0),
        'Review · ch 5 · 40 ayahs',
      );
      expect(
        en.command(_log(), today: _today, willLog: 30, skipped: 10),
        'Review · ch 5 · 30 ayahs (10 left out)',
      );
      expect(
        en.command(_log(), today: _today, willLog: 0, skipped: 7),
        'Review · ch 5 · nothing fits',
      );
    });

    test('a log for another day says the day', () {
      expect(
        en.command(_log(day: _today.plusDays(-1)), today: _today),
        'Review · ch 5 · 2024-10-03',
      );
    });

    test('French', () {
      expect(
        fr.command(_log(), today: _today, willLog: 40, skipped: 0),
        'Réviser · ch 5 · 40 ayahs',
      );
    });
  });

  group('every instruction and every result has words, in both languages', () {
    final commands = <AgentCommand>[
      _log(),
      _log(kind: MemoKind.m),
      const LogDayCommand(null),
      const LogDayCommand(_today),
      for (final screen in AgentScreen.values)
        OpenCommand(ScreenPlace(screen)),
      const OpenCommand(PagePlace(12)),
      const OpenCommand(SurahPlace(2)),
      const OpenCommand(ChPlace(5)),
      const OpenCommand(JuzPlace(30)),
      const OpenCommand(PartPlace(2, 5)),
      const OpenCommand(RangePlace(12, 20)),
      const OpenCommand(AyahPlace(AyahRef(2, 255), view: 'words')),
      const OpenCommand(AyahPlace(AyahRef(2, 255))),
      const OpenCommand(TafsirPlace(AyahRef(2, 255))),
      const OpenCommand(AskPlace()),
      const OpenCommand(AskPlace(ayah: AyahRef(2, 255), prompt: 'Why?')),
      // Every setting of the catalog, with a value of its kind.
      for (final spec in AgentCatalog.all)
        SetCommand(spec, switch (spec.kind) {
          AgentValueKind.flag => true,
          AgentValueKind.number => spec.min,
          AgentValueKind.choice => spec.choices.first,
          AgentValueKind.text => 'a wish',
          AgentValueKind.word => 'ch',
        }),
      const PartitionSaveCommand(name: 'Mine', unit: 'mc', starts: [0, 10]),
      const PartitionSaveCommand(
        id: 'p1',
        name: 'Mine',
        unit: 'mc',
        starts: [0, 10],
      ),
      const PartitionDeleteCommand('p1'),
      const NoteCommand(NoteOp.add, page: 12, text: 'watch it'),
      const NoteCommand(NoteOp.remembered, id: 'n1'),
      const NoteCommand(NoteOp.restore, id: 'n1'),
      const NoteCommand(NoteOp.delete, id: 'n1'),
      for (final what in AgentErase.values) EraseCommand(what),
      for (final op in BackupOp.values) BackupCommand(op),
      const PlanCommand(),
      const UndoCommand(),
    ];

    test('the line of an instruction is never empty', () {
      for (final text in [en, fr]) {
        for (final c in commands) {
          expect(text.command(c, today: _today), isNotEmpty, reason: '$c');
        }
      }
    });

    test('the line of a result is never empty', () {
      for (final text in [en, fr]) {
        for (final c in commands) {
          for (final kind in AgentResultKind.values) {
            expect(
              text.result(
                AgentResult(command: c, kind: kind, ayahs: 3, skipped: 1),
                today: _today,
              ),
              isNotEmpty,
              reason: '$c $kind',
            );
          }
        }
      }
    });

    test('a log result gives the ayahs and what was left out', () {
      expect(
        en.result(
          AgentResult(
            command: _log(),
            kind: AgentResultKind.done,
            ayahs: 40,
            skipped: 2,
          ),
          today: _today,
        ),
        'Review logged on 40 ayahs · ch 5 (2 left out)',
      );
      expect(
        en.result(
          AgentResult(
            command: _log(kind: MemoKind.m),
            kind: AgentResultKind.nothingFits,
          ),
          today: _today,
        ),
        contains('already learned'),
      );
    });

    test('the planner that is not set up and nothing to undo are said plainly', () {
      expect(
        en.result(
          const AgentResult(
            command: PlanCommand(),
            kind: AgentResultKind.unavailable,
          ),
        ),
        contains('planner'),
      );
      expect(
        en.result(
          const AgentResult(
            command: UndoCommand(),
            kind: AgentResultKind.unavailable,
          ),
        ),
        'Nothing to undo.',
      );
    });
  });

  group('settings read as the app words them', () {
    test('a choice, a number, a flag, a text', () {
      expect(en.command(_set('rulesPreset', 'relaxed')), 'Status rules: Relaxed');
      expect(
        fr.command(_set('rulesPreset', 'relaxed')),
        'Règles des statuts: Détendu',
      );
      expect(
        en.command(_set('plannerMaxItems', 8)),
        'Most suggestions in a plan: 8',
      );
      expect(en.command(_set('keepAwake', true)), contains('On'));
      expect(fr.command(_set('keepAwake', false)), contains('Désactivé'));
      expect(en.command(_set('theme', 'dark')), 'Theme: Dark');
      expect(en.command(_set('plannerModel', '')), contains('(default)'));
    });

    test('a long text is cut in the line', () {
      expect(
        en.command(_set('plannerWishes', 'w' * 500)).length,
        lessThan(120),
      );
    });

    test('a rule is shown by its key', () {
      expect(en.command(_set('rule.target.1', 9)), 'Rule target.1: 9');
    });
  });

  group('places, partitions, notes and the rest', () {
    test('places', () {
      expect(
        en.command(const OpenCommand(PagePlace(12))),
        'Open page 12',
      );
      expect(
        en.command(const OpenCommand(AyahPlace(AyahRef(2, 255), view: 'words'))),
        'Open 2:255 (words)',
      );
      expect(
        en.command(const OpenCommand(TafsirPlace(AyahRef(2, 255)))),
        'Open the tafsir of 2:255',
      );
      expect(
        en.command(const OpenCommand(ScreenPlace(AgentScreen.statusRules))),
        'Open Status rules',
      );
      expect(
        fr.command(const OpenCommand(PagePlace(12))),
        'Ouvrir la page 12',
      );
    });

    test('a partition or a note is named by what the user knows it by', () {
      expect(
        en.command(
          const PartitionDeleteCommand('p1'),
          names: const {'p1': 'My ch'},
        ),
        'Delete partition “My ch”',
      );
      expect(
        en.command(
          const NoteCommand(NoteOp.delete, id: 'n1'),
          names: const {'n1': 'watch the end'},
        ),
        'Delete the note “watch the end”',
      );
      // An id nobody knows is not invented.
      expect(
        en.command(const PartitionDeleteCommand('p9')),
        'Delete partition “p9”',
      );
    });

    test('what is irreversible is worded as such', () {
      expect(
        en.command(const EraseCommand(AgentErase.log)),
        'Erase the whole log',
      );
      expect(
        en.command(const BackupCommand(BackupOp.restore)),
        contains('replaces everything'),
      );
      expect(en.destructiveWarning, contains('always waits'));
      expect(fr.destructiveWarning, contains('toujours'));
    });
  });

  group('failures', () {
    test('a missing key sends the user to the settings', () {
      expect(
        en.failure(
          AgentFailure.provider,
          kind: AiErrorKind.missingKey,
          message: 'No Gemini API key stored',
        ),
        contains('Settings'),
      );
    });

    test('another provider error shows the provider\'s own words', () {
      expect(
        en.failure(
          AgentFailure.provider,
          kind: AiErrorKind.http,
          message: 'Gemini HTTP 500',
        ),
        'Gemini HTTP 500',
      );
    });

    test('every failure has a sentence', () {
      for (final text in [en, fr]) {
        for (final f in AgentFailure.values) {
          expect(text.failure(f), isNotEmpty);
        }
      }
    });
  });

  test('the dropped note counts', () {
    expect(en.dropped(1), startsWith('1 instruction was'));
    expect(en.dropped(3), startsWith('3 instructions were'));
  });
}
