import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/models/agent_command.dart';
import 'package:personaltskmng/agent/protocol/agent_parser.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';

// 2024-10-04, a Friday.
const Day _today = Day(20000);

final List<Partition> _partitions = [
  ...NaturalPartitions.all(PageMap.standard),
  Partition.originalCh(),
];

AgentReply? _parse(String text) =>
    AgentParser.parse(text, partitions: _partitions, today: _today);

String _actions(String actions) => '{"say":"ok","actions":[$actions]}';

/// The one command of an answer with one instruction (null when it was dropped).
AgentCommand? _one(String action) {
  final reply = _parse(_actions(action))!;
  return reply.commands.isEmpty ? null : reply.commands.single;
}

void main() {
  group('the answer as a whole', () {
    test('reads the sentence and the instructions', () {
      final reply = _parse(
        '{"say":"Logging.","actions":[{"do":"log","op":"R","range":"ch 5"}]}',
      )!;

      expect(reply.say, 'Logging.');
      expect(reply.dropped, 0);
      final log = reply.commands.single as LogCommand;
      expect(log.kind, MemoKind.r);
      expect(log.span, Partition.originalCh().spanOf(5));
      expect(log.day, _today);
      expect(log.rangeText, 'ch 5');
    });

    test('ignores a code fence and text around the JSON', () {
      final reply = _parse(
        'Sure!\n```json\n{"say":"Hi","actions":[]}\n```\nAnything else?',
      )!;
      expect(reply.say, 'Hi');
      expect(reply.commands, isEmpty);
    });

    test('a plain answer with no actions is fine', () {
      final reply = _parse('{"say":"Did you memorise it or review it?"}')!;
      expect(reply.commands, isEmpty);
      expect(reply.say, contains('memorise'));
    });

    test('is null for what is not an answer in the app language', () {
      expect(_parse('hello'), isNull);
      expect(_parse('{not json}'), isNull);
      expect(_parse('[1,2]'), isNull);
      expect(_parse('{"something":"else"}'), isNull);
    });

    test('an unknown instruction is dropped and counted, never guessed', () {
      final reply = _parse(
        _actions(
          '{"do":"format","what":"everything"},{"do":"open","page":12},'
          '"junk",{"nothing":1}',
        ),
      )!;
      expect(reply.commands.single, isA<OpenCommand>());
      expect(reply.dropped, 3);
    });

    test('the name of an instruction may be written loosely', () {
      expect(_one('{"do":"logDay","day":"yesterday"}'), isA<LogDayCommand>());
      expect(_one('{"do":"LOG_DAY","day":"yesterday"}'), isA<LogDayCommand>());
      expect(_one('{"action":"plan"}'), isA<PlanCommand>());
    });

    test('at most ${AgentParser.maxCommands} instructions are taken', () {
      final many = List.filled(14, '{"do":"plan"}').join(',');
      final reply = _parse(_actions(many))!;
      expect(reply.commands, hasLength(AgentParser.maxCommands));
      expect(reply.dropped, 14 - AgentParser.maxCommands);
    });

    test('a very long sentence is cut', () {
      final reply = _parse('{"say":"${'a' * 2000}","actions":[]}')!;
      expect(reply.say.length, lessThan(AgentParser.maxSayLength + 5));
    });
  });

  group('log', () {
    test('memorise and review, by word or letter, in any case', () {
      for (final op in ['M', 'm', 'memorise', 'Memorize']) {
        final c = _one('{"do":"log","op":"$op","range":"p 12"}');
        expect((c as LogCommand).kind, MemoKind.m, reason: op);
      }
      for (final op in ['R', 'review', 'Revise']) {
        final c = _one('{"do":"log","op":"$op","range":"p 12"}');
        expect((c as LogCommand).kind, MemoKind.r, reason: op);
      }
    });

    test('pieces, pages and ayahs all go through the typed-log reader', () {
      for (final range in ['p 12-15', '12', 's 2', 'j 30', '2:255-260']) {
        expect(_one('{"do":"log","op":"R","range":"$range"}'), isNotNull,
            reason: range);
      }
    });

    test('a range that does not exist is dropped', () {
      for (final range in ['ch 99', 'p 700', '2:300', 'banana', '']) {
        expect(_one('{"do":"log","op":"R","range":"$range"}'), isNull,
            reason: range);
      }
    });

    test('an unknown op, or a missing op or range, is dropped', () {
      for (final a in [
        '{"do":"log","op":"X","range":"p 1"}',
        '{"do":"log","range":"p 1"}',
        '{"do":"log","op":"R"}',
      ]) {
        expect(_one(a), isNull, reason: a);
      }
    });

    test('days: today, yesterday, a date', () {
      Day? dayOf(String day) {
        final c = _one('{"do":"log","op":"R","range":"p 1","day":"$day"}');
        return c == null ? null : (c as LogCommand).day;
      }

      expect(dayOf('today'), _today);
      expect(dayOf('Yesterday'), _today.plusDays(-1));
      expect(dayOf('2024-10-01'), Day.fromDate(2024, 10, 1));
      expect(dayOf('2024-10-04'), _today);
    });

    test('days that cannot be logged drop the instruction', () {
      for (final day in [
        '2024-10-05', // tomorrow
        '2024-02-30', // not a date
        '2019-12-31', // before the calendar starts
        '2024-13-01',
        'last friday',
        '04/10/2024',
      ]) {
        expect(
          _one('{"do":"log","op":"R","range":"p 1","day":"$day"}'),
          isNull,
          reason: day,
        );
      }
    });
  });

  group('logDay', () {
    test('today is "follow midnight", the others are days', () {
      expect((_one('{"do":"logDay","day":"today"}') as LogDayCommand).day, isNull);
      expect(
        (_one('{"do":"logDay","day":"yesterday"}') as LogDayCommand).day,
        _today.plusDays(-1),
      );
      expect(
        (_one('{"do":"logDay","day":"2024-10-01"}') as LogDayCommand).day,
        Day.fromDate(2024, 10, 1),
      );
    });

    test('a day that cannot be logged, or none, is dropped', () {
      expect(_one('{"do":"logDay","day":"2024-10-05"}'), isNull);
      expect(_one('{"do":"logDay"}'), isNull);
      expect(_one('{"do":"logDay","day":3}'), isNull);
    });
  });

  group('open', () {
    AgentPlace? place(String fields) {
      final c = _one('{"do":"open",$fields}');
      return c == null ? null : (c as OpenCommand).place;
    }

    test('pages 1 to 604, as a number or a number in text', () {
      expect((place('"page":604') as PagePlace).page, 604);
      expect((place('"page":"12"') as PagePlace).page, 12);
      for (final page in ['0', '605', '-3', '"x"']) {
        expect(place('"page":$page'), isNull, reason: page);
      }
    });

    test('a surah, a ch, a juz', () {
      expect((place('"surah":114') as SurahPlace).surah, 114);
      expect(place('"surah":115'), isNull);
      expect((place('"ch":5') as ChPlace).ch, 5);
      expect(place('"ch":0'), isNull);
      expect(place('"ch":${AgentParser.chCount + 1}'), isNull);
      expect((place('"juz":30') as JuzPlace).juz, 30);
      expect(place('"juz":31'), isNull);
    });

    test('a surah inside a ch, and a run of pages', () {
      final part = place('"part":[2,5]') as PartPlace;
      expect((part.surah, part.ch), (2, 5));
      expect(place('"part":[2]'), isNull);
      expect(place('"part":[0,5]'), isNull);
      final range = place('"pages":[12,20]') as RangePlace;
      expect((range.from, range.to), (12, 20));
      expect(place('"pages":[20,12]'), isNull);
      expect(place('"pages":[1,605]'), isNull);
    });

    test('ayahs that exist, with an optional view', () {
      final plain = place('"ayah":"2:255"') as AyahPlace;
      expect(plain.ayah.key, const AyahRef(2, 255).key);
      expect(plain.view, isNull);
      expect((place('"ayah":"2:255","view":"Words"') as AyahPlace).view, 'words');
      expect((place('"ayah":"2:255","view":"nope"') as AyahPlace).view, isNull);
      expect(place('"ayah":"2:300"'), isNull);
      expect(place('"ayah":5'), isNull);
    });

    test('a tafsir', () {
      expect((place('"tafsir":"2:255"') as TafsirPlace).ayah.key, '2:255');
      expect(place('"tafsir":"999:1"'), isNull);
    });

    test('the assistant, empty or with an ayah and a question', () {
      expect(place('"assistant":true'), isA<AskPlace>());
      final ask = place(
        '"assistant":{"ayah":"2:255","prompt":" What does it teach? "}',
      ) as AskPlace;
      expect(ask.ayah!.key, '2:255');
      expect(ask.prompt, 'What does it teach?');
      expect(place('"assistant":{"ayah":"2:999"}'), isNull);
      expect(place('"assistant":{"prompt":"${'a' * 501}"}'), isNull);
      expect(place('"assistant":"yes"'), isNull);
    });

    test('screens, written in any of the usual ways', () {
      final expected = {
        'today': AgentScreen.today,
        'Browse': AgentScreen.browse,
        'overview': AgentScreen.overview,
        'settings': AgentScreen.settings,
        'quran-data': AgentScreen.quranData,
        'quran_data': AgentScreen.quranData,
        'Quran data': AgentScreen.quranData,
        'chats': AgentScreen.chats,
        'status-rules': AgentScreen.statusRules,
        'status-guide': AgentScreen.statusGuide,
        'partitions': AgentScreen.partitions,
      };
      for (final entry in expected.entries) {
        final p = place('"screen":"${entry.key}"') as ScreenPlace;
        expect(p.screen, entry.value, reason: entry.key);
      }
      expect(place('"screen":"admin"'), isNull);
      expect(place('"nothing":1'), isNull);
    });
  });

  group('set', () {
    SetCommand? set(String setting, String value) {
      final c = _one('{"do":"set","setting":"$setting","value":$value}');
      return c == null ? null : c as SetCommand;
    }

    test('goes through the catalog: names, values and ranges', () {
      expect(set('theme', '"dark"')!.value, 'dark');
      expect(set('theme', '"auto"')!.value, 'system');
      expect(set('theme', '"purple"'), isNull);
      expect(set('reading_direction', '"left-to-right"')!.value, 'ltr');
      expect(set('keepSensible', '"off"')!.value, false);
      expect(set('attentionDays', '0'), isNull);
      expect(set('attentionLimit', '100')!.value, 100);
      expect(set('plannerMaxItems', '31'), isNull);
      expect(set('plannerWishes', '"Focus on review"')!.value, 'Focus on review');
      expect(set('plannerModel', '"default"')!.value, '');
      expect(set('textSize', '3')!.value, 3);
      expect(set('textSize', '4'), isNull);
      expect(set('readerView', '"details"')!.value, 'details');
    });

    test('any number of the status rules', () {
      final c = set('rule.target.1', '9')!;
      expect(c.spec.id, 'rule.target.1');
      expect(c.value, 9);
      expect(set('rule.forgive.2', '0')!.value, 0);
      expect(set('rule.target.1', '0'), isNull);
      expect(set('rule.nothing', '1'), isNull);
    });

    test('what is not on the list cannot be set', () {
      for (final name in [
        'apiKey',
        'plannerKey',
        'agentApproval',
        'agentEnabled',
        'manifestUrl',
        'googleDriveConnected',
        'googleDriveEmail',
      ]) {
        expect(set(name, '"x"'), isNull, reason: name);
      }
    });
  });

  group('partitions', () {
    test('a partition is read like the editor reads it', () {
      final c = _one(
        '{"do":"partition","op":"save","name":" My ch ","unit":"MC",'
        '"starts":["2:1","2:142","3:1"]}',
      ) as PartitionSaveCommand;
      expect(c.id, isNull);
      expect(c.name, 'My ch');
      expect(c.unit, 'mc');
      expect(c.starts, [
        const AyahRef(2, 1).index,
        const AyahRef(2, 142).index,
        const AyahRef(3, 1).index,
      ]);
    });

    test('starts may be one text, and an id means "replace"', () {
      final c = _one(
        '{"do":"partition","op":"edit","id":"p17","name":"X","unit":"xx",'
        '"starts":"p 5, p 10\\np 20"}',
      ) as PartitionSaveCommand;
      expect(c.id, 'p17');
      expect(c.starts, hasLength(3));
    });

    test('an unusable partition is dropped as a whole', () {
      for (final a in [
        '{"do":"partition","op":"save","name":"X","unit":"s","starts":["2:1"]}',
        '{"do":"partition","op":"save","name":"X","unit":"page","starts":["2:1"]}',
        '{"do":"partition","op":"save","name":"X","unit":"abcdefghi","starts":["2:1"]}',
        '{"do":"partition","op":"save","name":"X","unit":"a1","starts":["2:1"]}',
        '{"do":"partition","op":"save","name":"","unit":"xx","starts":["2:1"]}',
        '{"do":"partition","op":"save","name":"X","unit":"xx","starts":[]}',
        '{"do":"partition","op":"save","name":"X","unit":"xx","starts":["banana"]}',
        '{"do":"partition","op":"save","name":"X","unit":"xx"}',
        '{"do":"partition","op":"save","name":"X","unit":"xx","id":"a b","starts":["2:1"]}',
        '{"do":"partition","op":"merge","name":"X","unit":"xx","starts":["2:1"]}',
      ]) {
        expect(_one(a), isNull, reason: a);
      }
    });

    test('delete needs an id', () {
      expect(
        (_one('{"do":"partition","op":"delete","id":"p17"}')
                as PartitionDeleteCommand)
            .id,
        'p17',
      );
      expect(_one('{"do":"partition","op":"delete"}'), isNull);
    });
  });

  group('notes', () {
    test('add: a page and a text, optionally the surah and the ch', () {
      final c = _one(
        '{"do":"note","op":"add","page":12,"text":" watch the end ","s":2,"ch":5}',
      ) as NoteCommand;
      expect(c.op, NoteOp.add);
      expect((c.page, c.text, c.s, c.ch), (12, 'watch the end', 2, 5));
    });

    test('add: refuses a missing page or text, or a page that does not exist', () {
      for (final a in [
        '{"do":"note","op":"add","text":"x"}',
        '{"do":"note","op":"add","page":12}',
        '{"do":"note","op":"add","page":12,"text":"   "}',
        '{"do":"note","op":"add","page":605,"text":"x"}',
        '{"do":"note","op":"add","page":12,"text":"${'a' * 501}"}',
        '{"do":"note","op":"add","page":12,"text":"x","s":200}',
      ]) {
        expect(_one(a), isNull, reason: a);
      }
    });

    test('the others name a note', () {
      for (final op in ['remembered', 'restore', 'delete']) {
        final c = _one('{"do":"note","op":"$op","id":"n-1"}') as NoteCommand;
        expect(c.id, 'n-1');
        expect(_one('{"do":"note","op":"$op"}'), isNull, reason: op);
        expect(_one('{"do":"note","op":"$op","id":"a b"}'), isNull, reason: op);
      }
    });
  });

  group('erase and backup', () {
    test('what can be erased', () {
      expect((_one('{"do":"erase","what":"log"}') as EraseCommand).what,
          AgentErase.log);
      expect((_one('{"do":"erase","what":"Reading"}') as EraseCommand).what,
          AgentErase.reading);
      expect((_one('{"do":"erase","what":"chats"}') as EraseCommand).what,
          AgentErase.chats);
      expect(_one('{"do":"erase","what":"notes"}'), isNull);
      expect(_one('{"do":"erase","what":"everything"}'), isNull);
      expect(_one('{"do":"erase"}'), isNull);
    });

    test('backup now, or restore', () {
      expect((_one('{"do":"backup","op":"now"}') as BackupCommand).op,
          BackupOp.now);
      expect((_one('{"do":"backup","op":"restore"}') as BackupCommand).op,
          BackupOp.restore);
      expect(_one('{"do":"backup","op":"delete"}'), isNull);
    });
  });

  test('plan and undo need no fields', () {
    final c = _parse(_actions('{"do":"plan"},{"do":"undo"}'))!;
    expect(c.commands[0], isA<PlanCommand>());
    expect(c.commands[1], isA<UndoCommand>());
  });

  group('who must say yes', () {
    test('looking is free', () {
      for (final c in <AgentCommand>[
        const PlanCommand(),
        const UndoCommand(),
        const LogDayCommand(null),
        const OpenCommand(PagePlace(1)),
        const OpenCommand(ScreenPlace(AgentScreen.today)),
      ]) {
        expect(c.risk, AgentRisk.free, reason: '$c');
        expect(c.changesData, isFalse);
        expect(c.alwaysAsk, isFalse);
      }
    });

    test('changing is shown first when the agent asks', () {
      final log = _one('{"do":"log","op":"R","range":"p 1"}')!;
      final set = _one('{"do":"set","setting":"theme","value":"dark"}')!;
      final save = _one(
        '{"do":"partition","op":"save","name":"X","unit":"xx","starts":["2:1"]}',
      )!;
      final add = _one('{"do":"note","op":"add","page":1,"text":"x"}')!;
      final remember = _one('{"do":"note","op":"remembered","id":"n"}')!;
      final now = _one('{"do":"backup","op":"now"}')!;
      final del = _one('{"do":"partition","op":"delete","id":"p1"}')!;
      for (final c in [log, set, save, add, remember, now, del]) {
        expect(c.risk, AgentRisk.change, reason: '$c');
        expect(c.changesData, isTrue);
        expect(c.alwaysAsk, isFalse);
      }
    });

    test('what cannot be undone always asks', () {
      for (final a in [
        '{"do":"erase","what":"log"}',
        '{"do":"erase","what":"reading"}',
        '{"do":"erase","what":"chats"}',
        '{"do":"note","op":"delete","id":"n"}',
        '{"do":"backup","op":"restore"}',
      ]) {
        final c = _one(a)!;
        expect(c.risk, AgentRisk.destructive, reason: a);
        expect(c.alwaysAsk, isTrue, reason: a);
      }
    });
  });
}
