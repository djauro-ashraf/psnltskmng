import 'dart:convert';

import 'package:personaltskmng/agent/models/agent_catalog.dart';
import 'package:personaltskmng/agent/models/agent_command.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/rules/range_input.dart';

/// What came back from the agent's AI: a sentence for the user and the
/// instructions the app understood.
final class AgentReply {
  const AgentReply({
    required this.say,
    required this.commands,
    this.dropped = 0,
  });

  /// What the AI says it is doing (or its answer, or its question). Never a
  /// claim about what the app did: the app reports that itself.
  final String say;

  final List<AgentCommand> commands;

  /// Instructions that were not understood or not allowed, and so ignored.
  final int dropped;
}

/// Reads the AI's JSON answer in the app's language. Tolerant about the
/// wrapping (a code fence or text around the JSON is ignored) and strict about
/// the content: an instruction it cannot read exactly is counted in
/// [AgentReply.dropped], never repaired or guessed. Ranges go through
/// `RangeInput`, the same reader as the typed log; settings go through
/// [AgentCatalog]. Pure Dart.
abstract final class AgentParser {
  /// At most this many instructions are taken from one answer.
  static const int maxCommands = 10;

  /// The longest sentence kept of the AI's own words.
  static const int maxSayLength = 600;

  /// A day to log for cannot be before this (the calendar on Today stops here).
  static final Day earliestDay = Day.fromDate(2020, 1, 1);

  /// How many pieces the user's original ch has.
  static final int chCount = Partition.originalCh().count;

  /// Units the natural partitions use: a partition of the user's cannot.
  static const Set<String> reservedUnits = {
    's', 'j', 'hz', 'ru', 'p', 'surah', 'juz', 'hizb', 'ruku', 'page', 'pg',
    'sura',
  };

  static final RegExp _date = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');
  static final RegExp _unit = RegExp(r'^[a-z]{1,8}$');
  static final RegExp _idShape = RegExp(r'^[A-Za-z0-9_.:\-]{1,64}$');
  static final RegExp _separators = RegExp(r'[\n,;]+');

  /// Null when [text] holds no usable JSON object at all.
  static AgentReply? parse(
    String text, {
    required List<Partition> partitions,
    required Day today,
  }) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(text.substring(start, end + 1));
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;

    final rawActions = decoded['actions'];
    final say = _say(decoded);
    // A JSON object that has neither a sentence nor a list of actions is not
    // an answer in the app's language.
    if (say == null && rawActions is! List) return null;

    final commands = <AgentCommand>[];
    var dropped = 0;
    if (rawActions is List) {
      for (final raw in rawActions) {
        if (commands.length >= maxCommands) {
          dropped++;
          continue;
        }
        final command = _command(raw, partitions, today);
        if (command == null) {
          dropped++;
        } else {
          commands.add(command);
        }
      }
    }
    return AgentReply(say: say ?? '', commands: commands, dropped: dropped);
  }

  static String? _say(Map<dynamic, dynamic> decoded) {
    for (final key in const ['say', 'reply', 'message', 'text']) {
      final value = decoded[key];
      if (value is String) {
        final trimmed = value.trim();
        return trimmed.length > maxSayLength
            ? '${trimmed.substring(0, maxSayLength)}…'
            : trimmed;
      }
    }
    return null;
  }

  static AgentCommand? _command(
    Object? raw,
    List<Partition> partitions,
    Day today,
  ) {
    if (raw is! Map) return null;
    final action = raw['do'] ?? raw['action'];
    if (action is! String) return null;
    switch (action.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')) {
      case 'log':
        return _log(raw, partitions, today);
      case 'logday':
        return _logDay(raw, today);
      case 'open':
        return _open(raw);
      case 'set':
        return _set(raw);
      case 'partition':
        return _partition(raw, partitions);
      case 'note':
        return _note(raw);
      case 'erase':
        return _erase(raw);
      case 'backup':
        return _backup(raw);
      case 'plan':
        return const PlanCommand();
      case 'undo':
        return const UndoCommand();
      default:
        return null;
    }
  }

  // -- log ----------------------------------------------------------------------

  static AgentCommand? _log(
    Map<dynamic, dynamic> raw,
    List<Partition> partitions,
    Day today,
  ) {
    final op = raw['op'];
    final range = raw['range'];
    if (op is! String || range is! String) return null;
    final kind = _kind(op);
    if (kind == null) return null;
    final span = RangeInput.parse(range, partitions).span;
    if (span == null) return null;
    final day = _day(raw['day'], today);
    if (day == null) return null;
    return LogCommand(
      kind: kind,
      span: span,
      day: day,
      rangeText: range.trim(),
    );
  }

  static MemoKind? _kind(String op) {
    switch (op.trim().toLowerCase()) {
      case 'm':
      case 'memorise':
      case 'memorize':
      case 'memorised':
      case 'memorized':
        return MemoKind.m;
      case 'r':
      case 'review':
      case 'revise':
      case 'reviewed':
      case 'revised':
        return MemoKind.r;
      default:
        return null;
    }
  }

  /// Today when absent; otherwise "today", "yesterday" or a real date from
  /// 2020-01-01 up to today. Null (the instruction is dropped) for anything
  /// else: a wrong day in the log is worse than no line.
  static Day? _day(Object? value, Day today) {
    if (value == null) return today;
    if (value is! String) return null;
    final text = value.trim().toLowerCase();
    if (text.isEmpty || text == 'today') return today;
    if (text == 'yesterday') return today.plusDays(-1);
    final match = _date.firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final parsed = Day.fromDate(year, month, day);
    // 2026-02-30 would roll over to March: it is not a date.
    if (parsed.toString() != text) return null;
    if (parsed.isAfter(today) || parsed.isBefore(earliestDay)) return null;
    return parsed;
  }

  static AgentCommand? _logDay(Map<dynamic, dynamic> raw, Day today) {
    final value = raw['day'];
    if (value is! String) return null;
    final day = _day(value, today);
    if (day == null) return null;
    return LogDayCommand(day == today ? null : day);
  }

  // -- open ---------------------------------------------------------------------

  static AgentCommand? _open(Map<dynamic, dynamic> raw) {
    if (raw['page'] != null) {
      final page = _int(raw['page']);
      if (page == null || page < 1 || page > PageMap.pageCount) return null;
      return OpenCommand(PagePlace(page));
    }
    if (raw['surah'] != null) {
      final surah = _int(raw['surah']);
      if (surah == null || surah < 1 || surah > QuranDivisions.surahCount) {
        return null;
      }
      return OpenCommand(SurahPlace(surah));
    }
    if (raw['ch'] != null) {
      final ch = _int(raw['ch']);
      if (ch == null || ch < 1 || ch > chCount) return null;
      return OpenCommand(ChPlace(ch));
    }
    if (raw['juz'] != null) {
      final juz = _int(raw['juz']);
      if (juz == null || juz < 1 || juz > QuranDivisions.juzCount) return null;
      return OpenCommand(JuzPlace(juz));
    }
    if (raw['part'] != null) {
      final both = _pair(raw['part']);
      if (both == null) return null;
      final (s, ch) = both;
      if (s < 1 || s > QuranDivisions.surahCount || ch < 1 || ch > chCount) {
        return null;
      }
      return OpenCommand(PartPlace(s, ch));
    }
    if (raw['pages'] != null) {
      final both = _pair(raw['pages']);
      if (both == null) return null;
      final (from, to) = both;
      if (from < 1 || to > PageMap.pageCount || from > to) return null;
      return OpenCommand(RangePlace(from, to));
    }
    if (raw['tafsir'] != null) {
      final ayah = _ayah(raw['tafsir']);
      return ayah == null ? null : OpenCommand(TafsirPlace(ayah));
    }
    if (raw['assistant'] != null) return _ask(raw['assistant']);
    if (raw['ayah'] != null) {
      final ayah = _ayah(raw['ayah']);
      if (ayah == null) return null;
      final view = raw['view'];
      String? name;
      if (view is String) {
        final word = view.trim().toLowerCase();
        if (word == 'mushaf' || word == 'words' || word == 'details') {
          name = word;
        }
      }
      return OpenCommand(AyahPlace(ayah, view: name));
    }
    final screen = raw['screen'];
    if (screen is String) {
      final place = _screen(screen);
      return place == null ? null : OpenCommand(ScreenPlace(place));
    }
    return null;
  }

  static AgentCommand? _ask(Object? value) {
    if (value == true) return const OpenCommand(AskPlace());
    if (value is! Map) return null;
    final rawAyah = value['ayah'];
    AyahRef? ayah;
    if (rawAyah != null) {
      ayah = _ayah(rawAyah);
      if (ayah == null) return null;
    }
    final rawPrompt = value['prompt'];
    String? prompt;
    if (rawPrompt != null) {
      if (rawPrompt is! String) return null;
      final trimmed = rawPrompt.trim();
      if (trimmed.length > 500) return null;
      prompt = trimmed.isEmpty ? null : trimmed;
    }
    return OpenCommand(AskPlace(ayah: ayah, prompt: prompt));
  }

  static AgentScreen? _screen(String name) {
    switch (name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')) {
      case 'today':
        return AgentScreen.today;
      case 'browse':
        return AgentScreen.browse;
      case 'overview':
        return AgentScreen.overview;
      case 'settings':
        return AgentScreen.settings;
      case 'qurandata':
        return AgentScreen.quranData;
      case 'chats':
      case 'chat':
      case 'assistant':
        return AgentScreen.chats;
      case 'statusrules':
      case 'rules':
        return AgentScreen.statusRules;
      case 'statusguide':
      case 'guide':
        return AgentScreen.statusGuide;
      case 'partitions':
        return AgentScreen.partitions;
      default:
        return null;
    }
  }

  static AyahRef? _ayah(Object? value) {
    if (value is! String) return null;
    return AyahRef.tryParse(value.trim());
  }

  /// Two whole numbers from a list of two, else null.
  static (int, int)? _pair(Object? value) {
    if (value is! List || value.length != 2) return null;
    final a = _int(value[0]);
    final b = _int(value[1]);
    if (a == null || b == null) return null;
    return (a, b);
  }

  // -- set ----------------------------------------------------------------------

  static AgentCommand? _set(Map<dynamic, dynamic> raw) {
    final name = raw['setting'];
    if (name is! String) return null;
    final spec = AgentCatalog.byId(name);
    if (spec == null) return null;
    final value = spec.normalise(raw['value']);
    if (value == null) return null;
    return SetCommand(spec, value);
  }

  // -- partitions ---------------------------------------------------------------

  static AgentCommand? _partition(
    Map<dynamic, dynamic> raw,
    List<Partition> partitions,
  ) {
    final op = _word(raw['op']);
    final rawId = raw['id'];
    String? id;
    if (rawId != null) {
      if (rawId is! String || !_idShape.hasMatch(rawId.trim())) return null;
      id = rawId.trim();
    }
    if (op == 'delete' || op == 'remove') {
      return id == null ? null : PartitionDeleteCommand(id);
    }
    if (op != 'save' && op != 'create' && op != 'add' && op != 'edit') {
      return null;
    }
    final name = raw['name'];
    final unit = raw['unit'];
    if (name is! String || unit is! String) return null;
    final cleanName = name.trim();
    final cleanUnit = unit.trim().toLowerCase();
    if (cleanName.isEmpty || cleanName.length > 40) return null;
    if (!_unit.hasMatch(cleanUnit) || reservedUnits.contains(cleanUnit)) {
      return null;
    }
    final tokens = <String>[];
    final rawStarts = raw['starts'];
    if (rawStarts is String) {
      tokens.addAll(rawStarts.split(_separators));
    } else if (rawStarts is List) {
      for (final item in rawStarts) {
        if (item is! String) return null;
        tokens.addAll(item.split(_separators));
      }
    } else {
      return null;
    }
    final starts = <int>[];
    for (final piece in tokens) {
      final token = piece.trim();
      if (token.isEmpty) continue;
      final span = RangeInput.parse(token, partitions).span;
      if (span == null) return null;
      starts.add(span.first);
    }
    if (starts.isEmpty || starts.length > 700) return null;
    return PartitionSaveCommand(
      id: id,
      name: cleanName,
      unit: cleanUnit,
      starts: starts,
    );
  }

  // -- notes --------------------------------------------------------------------

  static AgentCommand? _note(Map<dynamic, dynamic> raw) {
    final op = _word(raw['op']);
    if (op == 'add') {
      final page = _int(raw['page']);
      final text = raw['text'];
      if (page == null || page < 1 || page > PageMap.pageCount) return null;
      if (text is! String) return null;
      final clean = text.trim();
      if (clean.isEmpty || clean.length > 500) return null;
      int? s;
      int? ch;
      if (raw['s'] != null) {
        s = _int(raw['s']);
        if (s == null || s < 1 || s > QuranDivisions.surahCount) return null;
      }
      if (raw['ch'] != null) {
        ch = _int(raw['ch']);
        if (ch == null || ch < 1 || ch > chCount) return null;
      }
      return NoteCommand(NoteOp.add, page: page, text: clean, s: s, ch: ch);
    }
    final rawId = raw['id'];
    if (rawId is! String || !_idShape.hasMatch(rawId.trim())) return null;
    final id = rawId.trim();
    switch (op) {
      case 'remembered':
      case 'remember':
        return NoteCommand(NoteOp.remembered, id: id);
      case 'restore':
        return NoteCommand(NoteOp.restore, id: id);
      case 'delete':
        return NoteCommand(NoteOp.delete, id: id);
      default:
        return null;
    }
  }

  // -- erase and backup ---------------------------------------------------------

  static AgentCommand? _erase(Map<dynamic, dynamic> raw) {
    switch (_word(raw['what'])) {
      case 'log':
        return const EraseCommand(AgentErase.log);
      case 'reading':
        return const EraseCommand(AgentErase.reading);
      case 'chats':
        return const EraseCommand(AgentErase.chats);
      default:
        return null;
    }
  }

  static AgentCommand? _backup(Map<dynamic, dynamic> raw) {
    switch (_word(raw['op'])) {
      case 'now':
        return const BackupCommand(BackupOp.now);
      case 'restore':
        return const BackupCommand(BackupOp.restore);
      default:
        return null;
    }
  }

  // -- small readers ------------------------------------------------------------

  static String? _word(Object? value) =>
      value is String ? value.trim().toLowerCase() : null;

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is double && value == value.roundToDouble()) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}
