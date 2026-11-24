import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/agent/controller/agent_providers.dart';
import 'package:personaltskmng/agent/models/agent_command.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/agent/models/agent_turn.dart';
import 'package:personaltskmng/agent/protocol/agent_parser.dart';
import 'package:personaltskmng/agent/protocol/agent_prompt.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ask/controller/ask_providers.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/features/agent/presentation/providers/agent_settings_io.dart';
import 'package:personaltskmng/features/backup/presentation/providers/backup_providers.dart';
import 'package:personaltskmng/features/browse/domain/browse_index.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/browse_paths.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/memo/presentation/providers/reading_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';
import 'package:personaltskmng/features/today/presentation/viewmodels/plan_view_model.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';

/// The agent's conversation: takes what the user typed, asks the agent's AI
/// (with a picture of the app), reads the answer in the app's language and
/// carries the instructions out through the same controllers every screen uses.
/// The AI never touches data: it can only produce instructions from a closed
/// list, each one is checked by `AgentParser` and then done by the app, under
/// the app's own rules (a log still goes through the memorise / review rule, a
/// setting through the notifier of its settings screen).
///
/// Who must say yes: a `free` command (open, plan, undo, choose the log day) is
/// done at once; a `change` is shown first when the agent is set to "ask before
/// doing"; a `destructive` one (erase, delete a note, restore a backup) is
/// ALWAYS shown first, whatever the mode: the AI can never replace that tap.
///
/// Not a real agent loop: one question, one answer, one round of instructions.
/// What the app did is told to the AI with the user's next message.
///
/// The conversation lives as long as the app is open; it is never stored.
class AgentController extends Notifier<AgentChatState> {
  /// How many earlier turns go to the AI as history.
  static const int historyTurns = 3;

  int _seq = 0;

  @override
  AgentChatState build() => const AgentChatState();

  // -- asking -------------------------------------------------------------------

  /// Takes the user's request. Does nothing while a request is being handled.
  /// A turn that was waiting for approval is cancelled: the user moved on.
  Future<void> send(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || state.busy) return;
    final id = 'turn_${++_seq}';
    final earlier = state.turns;
    // A new request starts with no route waiting (a stale one must never fire).
    state = AgentChatState(
      turns: [
        for (final t in earlier)
          t.phase == AgentPhase.pending
              ? t.copyWith(phase: AgentPhase.cancelled)
              : t,
        AgentTurn(id: id, userText: clean, phase: AgentPhase.thinking),
      ],
    );

    final client = ref.read(agentClientProvider);
    if (client == null) {
      _change(
        id,
        (t) => t.copyWith(phase: AgentPhase.failed, failure: AgentFailure.noAi),
      );
      return;
    }

    final List<AiMessage> messages;
    try {
      messages = await _messages(clean, [
        for (final t in state.turns)
          if (t.id != id) t,
      ]);
    } catch (_) {
      _change(
        id,
        (t) => t.copyWith(phase: AgentPhase.failed, failure: AgentFailure.other),
      );
      return;
    }
    if (!ref.mounted) return;

    final String raw;
    try {
      raw = await client.generateJson(
        system: AgentPrompt.system,
        messages: messages,
      );
    } on AiProviderException catch (e) {
      _change(
        id,
        (t) => t.copyWith(
          phase: AgentPhase.failed,
          failure: AgentFailure.provider,
          error: e.message,
          errorKind: e.kind,
        ),
      );
      return;
    } catch (_) {
      _change(
        id,
        (t) => t.copyWith(phase: AgentPhase.failed, failure: AgentFailure.other),
      );
      return;
    }
    if (!ref.mounted) return;

    // Read against the app as it is now (the answer took a while).
    final memo = ref.read(memoProvider);
    final reply = AgentParser.parse(
      raw,
      partitions: memo.partitions,
      today: memo.today,
    );
    if (reply == null) {
      _change(
        id,
        (t) => t.copyWith(
          phase: AgentPhase.failed,
          failure: AgentFailure.unreadable,
        ),
      );
      return;
    }
    _change(
      id,
      (t) => t.copyWith(
        say: reply.say,
        commands: reply.commands,
        dropped: reply.dropped,
        reply: raw,
      ),
    );

    if (reply.commands.isEmpty) {
      _change(id, (t) => t.copyWith(phase: AgentPhase.done));
      return;
    }
    if (needsApproval(
      reply.commands,
      ref.read(agentSettingsProvider).approval,
    )) {
      _change(id, (t) => t.copyWith(phase: AgentPhase.pending));
      return;
    }
    await _run(id);
  }

  /// Whether [commands] must be shown to the user before anything is done.
  /// A destructive command always asks; a change asks when [approval] is
  /// [AgentApproval.ask]; looking never asks.
  static bool needsApproval(
    List<AgentCommand> commands,
    AgentApproval approval,
  ) =>
      commands.any((c) => c.alwaysAsk) ||
      (approval == AgentApproval.ask && commands.any((c) => c.changesData));

  /// What goes to the AI: the last few answered turns as history, then the
  /// user's words with the picture of the app as it is now.
  Future<List<AiMessage>> _messages(String text, List<AgentTurn> earlier) async {
    final answered = [
      for (final t in earlier)
        if (t.reply != null) t,
    ];
    final recent = answered.length > historyTurns
        ? answered.sublist(answered.length - historyTurns)
        : answered;
    final memo = ref.read(memoProvider);
    final share = ref.read(agentSettingsProvider).shareNotes;

    List<({String id, int page, String text, bool open})>? notes;
    if (share) {
      final all = ref.read(notesViewModelProvider).book.notes;
      notes = [
        for (final n in all)
          if (n.isOpen) (id: n.id, page: n.page, text: n.text, open: true),
        for (final n in all)
          if (n.isArchived) (id: n.id, page: n.page, text: n.text, open: false),
      ];
    }

    var translations = <({String id, String title})>[];
    var tafsirs = <({String id, String title})>[];
    try {
      final installed = await ref
          .read(installedTranslationsProvider.future)
          .timeout(const Duration(seconds: 3));
      translations = [for (final p in installed) (id: p.id, title: p.title)];
    } catch (_) {
      // Not downloaded, or the storage is not there: none are listed.
    }
    try {
      final sources = await ref
          .read(tafsirSourcesProvider.future)
          .timeout(const Duration(seconds: 3));
      tafsirs = [for (final t in sources) (id: t.id, title: t.title)];
    } catch (_) {
      // Same.
    }

    return [
      for (final t in recent) ...[
        AiMessage(AiRole.user, AgentPrompt.plainUser(t.userText)),
        AiMessage(AiRole.assistant, t.reply!),
      ],
      AiMessage(
        AiRole.user,
        AgentPrompt.userMessage(
          text: text,
          today: memo.today,
          logDay: ref.read(logDayProvider),
          partition: memo.defaultPartition,
          partitions: memo.partitions,
          view: memo.view,
          pages: memo.pages,
          events: memo.data.events,
          settings: readAgentSettings(ref),
          plannerAvailable: ref.read(planViewModelProvider.notifier).available,
          lastActions: _lastActions(earlier),
          attentionDays: memo.settings.attentionDays,
          notes: notes,
          translations: translations,
          tafsirs: tafsirs,
        ),
      ),
    ];
  }

  /// What the app did with the previous answer, for the AI (English, one line
  /// each).
  static List<String> _lastActions(List<AgentTurn> earlier) {
    if (earlier.isEmpty) return const [];
    final last = earlier.last;
    if (last.phase == AgentPhase.cancelled && last.commands.isNotEmpty) {
      return const [
        'The user cancelled the previous instructions: nothing was done.',
      ];
    }
    return [for (final r in last.results) _modelLine(r)];
  }

  static String _modelLine(AgentResult r) {
    final what = describeForModel(r.command);
    switch (r.kind) {
      case AgentResultKind.done:
        if (r.command is LogCommand) {
          final left = r.skipped > 0 ? ', ${r.skipped} left out' : '';
          return '$what: ${r.ayahs} ayahs logged$left';
        }
        return '$what: done';
      case AgentResultKind.nothingFits:
        return '$what: nothing logged, it does not fit the memorise / review rule';
      case AgentResultKind.failed:
        return '$what: failed';
      case AgentResultKind.unavailable:
        return '$what: not possible right now';
    }
  }

  /// A command in a few English words, for the AI's history.
  static String describeForModel(AgentCommand command) => switch (command) {
    LogCommand c => 'log ${c.kind.letter} ${c.rangeText} on ${c.day}',
    LogDayCommand c => 'logDay ${c.day ?? 'today'}',
    OpenCommand c => 'open ${_placeForModel(c.place)}',
    SetCommand c => 'set ${c.spec.id} ${c.value}',
    PartitionSaveCommand c =>
      'partition save ${c.id ?? 'new'} ${c.unit} (${c.starts.length} pieces)',
    PartitionDeleteCommand c => 'partition delete ${c.id}',
    NoteCommand c => 'note ${c.op.name} ${c.id ?? 'page ${c.page}'}',
    EraseCommand c => 'erase ${c.what.name}',
    BackupCommand c => 'backup ${c.op.name}',
    PlanCommand _ => 'plan',
    UndoCommand _ => 'undo',
  };

  static String _placeForModel(AgentPlace place) => switch (place) {
    ScreenPlace p => p.screen.name,
    PagePlace p => 'page ${p.page}',
    SurahPlace p => 'surah ${p.surah}',
    ChPlace p => 'ch ${p.ch}',
    JuzPlace p => 'juz ${p.juz}',
    PartPlace p => 'surah ${p.surah} in ch ${p.ch}',
    AyahPlace p => 'ayah ${p.ayah.key}',
    RangePlace p => 'pages ${p.from}-${p.to}',
    TafsirPlace p => 'tafsir ${p.ayah.key}',
    AskPlace _ => 'assistant',
  };

  // -- deciding -----------------------------------------------------------------

  /// The user said yes to a turn that was waiting.
  Future<void> approve(String id) async {
    final turn = _find(id);
    if (turn == null || turn.phase != AgentPhase.pending || state.busy) return;
    await _run(id);
  }

  /// The user said no to a turn that was waiting: nothing is done.
  void cancel(String id) {
    final turn = _find(id);
    if (turn == null || turn.phase != AgentPhase.pending) return;
    _change(id, (t) => t.copyWith(phase: AgentPhase.cancelled));
  }

  /// Removes the logs a turn wrote (one tap, whatever their number).
  Future<void> undoTurn(String id) async {
    final turn = _find(id);
    if (turn == null || !turn.canUndo) return;
    final memo = ref.read(memoProvider.notifier);
    for (final group in turn.groups.reversed) {
      await memo.undo(group);
    }
    _change(id, (t) => t.copyWith(undone: true));
  }

  /// Starts again with an empty conversation (not while one is being handled).
  void clear() {
    if (state.busy) return;
    state = const AgentChatState();
  }

  /// The screen has taken the route it was given.
  void consumeRoute() {
    if (state.route == null) return;
    state = state.withRoute(null);
  }

  // -- doing --------------------------------------------------------------------

  Future<void> _run(String id) async {
    final turn = _find(id);
    if (turn == null) return;
    _change(id, (t) => t.copyWith(phase: AgentPhase.running));
    final results = <AgentResult>[];
    String? route;
    for (final command in turn.commands) {
      final result = await _execute(command, id);
      if (!ref.mounted) return;
      results.add(result);
      final to = result.route;
      if (to != null) route = to;
    }
    _change(
      id,
      (t) => t.copyWith(phase: AgentPhase.done, results: results),
    );
    if (route != null && ref.mounted) state = state.withRoute(route);
  }

  Future<AgentResult> _execute(AgentCommand command, String currentId) async {
    try {
      switch (command) {
        case final LogCommand c:
          return await _log(c);
        case final LogDayCommand c:
          ref.read(logDayProvider.notifier).choose(c.day);
          return _done(c);
        case final OpenCommand c:
          return _open(c);
        case final SetCommand c:
          return _result(c, await writeAgentSetting(ref, c.spec, c.value));
        case final PartitionSaveCommand c:
          return await _partitionSave(c);
        case final PartitionDeleteCommand c:
          return _result(
            c,
            await ref.read(memoProvider.notifier).deletePartition(c.id),
          );
        case final NoteCommand c:
          return await _note(c);
        case final EraseCommand c:
          return await _erase(c);
        case final BackupCommand c:
          return await _backup(c);
        case final PlanCommand c:
          return _plan(c);
        case final UndoCommand c:
          return await _undoLast(c, currentId);
      }
    } catch (_) {
      return AgentResult(command: command, kind: AgentResultKind.failed);
    }
  }

  static AgentResult _done(AgentCommand c, {String? route}) =>
      AgentResult(command: c, kind: AgentResultKind.done, route: route);

  static AgentResult _result(AgentCommand c, bool ok) => AgentResult(
    command: c,
    kind: ok ? AgentResultKind.done : AgentResultKind.failed,
  );

  // -- log ----------------------------------------------------------------------

  Future<AgentResult> _log(LogCommand c) async {
    final result = await ref
        .read(memoProvider.notifier)
        .log(kind: c.kind, span: c.span, day: c.day);
    return AgentResult(
      command: c,
      kind: result.wroteAnything
          ? AgentResultKind.done
          : AgentResultKind.nothingFits,
      ayahs: result.ayahs,
      skipped: result.skipped,
      group: result.group,
    );
  }

  // -- open ---------------------------------------------------------------------

  AgentResult _open(OpenCommand c) {
    final place = c.place;
    // A surah/ch pair the ch table does not list has no page to open.
    if (place is PartPlace &&
        BrowseIndex.instance.part(place.surah, place.ch) == null) {
      return AgentResult(command: c, kind: AgentResultKind.failed);
    }
    return _done(c, route: _path(place));
  }

  static String _path(AgentPlace place) => switch (place) {
    ScreenPlace p => _screenPath(p.screen),
    PagePlace p => BrowsePaths.readPage(p.page),
    SurahPlace p => BrowsePaths.readSurah(p.surah),
    ChPlace p => BrowsePaths.readCh(p.ch),
    JuzPlace p => BrowsePaths.readJuz(p.juz),
    PartPlace p => BrowsePaths.readPart(p.surah, p.ch),
    AyahPlace p => BrowsePaths.readAyah(
      p.ayah,
      view: p.view == null ? null : QuranView.values.asNameMap()[p.view],
    ),
    RangePlace p => BrowsePaths.readRange(p.from, p.to),
    TafsirPlace p => BrowsePaths.tafsirOf(p.ayah),
    AskPlace p => BrowsePaths.askNew(ayah: p.ayah, prompt: p.prompt),
  };

  static String _screenPath(AgentScreen screen) => switch (screen) {
    AgentScreen.today => AppRoutes.today,
    AgentScreen.browse => AppRoutes.browse,
    AgentScreen.overview => AppRoutes.overview,
    AgentScreen.settings => AppRoutes.settings,
    AgentScreen.quranData => AppRoutes.quranData,
    AgentScreen.chats => BrowsePaths.ask,
    AgentScreen.statusRules => AppRoutes.statusRules,
    AgentScreen.statusGuide => AppRoutes.statusGuide,
    AgentScreen.partitions => AppRoutes.partitions,
  };

  // -- partitions ---------------------------------------------------------------

  Future<AgentResult> _partitionSave(PartitionSaveCommand c) async {
    final memo = ref.read(memoProvider);
    final id = c.id;
    // Replacing one: it must be one of the user's own that exists.
    if (id != null && !memo.custom.any((p) => p.id == id)) {
      return AgentResult(command: c, kind: AgentResultKind.failed);
    }
    // A unit names one partition only (the typed log finds pieces by it).
    for (final p in memo.partitions) {
      if (p.unit == c.unit && p.id != id) {
        return AgentResult(command: c, kind: AgentResultKind.failed);
      }
    }
    await ref
        .read(memoProvider.notifier)
        .savePartition(
          Partition(
            id: id ?? 'p${DateTime.now().millisecondsSinceEpoch}',
            name: c.name,
            unit: c.unit,
            kind: PartitionKind.custom,
            starts: c.starts,
          ),
        );
    return _done(c);
  }

  // -- notes --------------------------------------------------------------------

  Future<AgentResult> _note(NoteCommand c) async {
    final notes = ref.read(notesViewModelProvider.notifier);
    final id = c.id;
    if (c.op == NoteOp.add) {
      final page = c.page!;
      final home = preselectedHome(noteHomesOfPage(page), s: c.s, ch: c.ch);
      return _result(
        c,
        await notes.add(page: page, s: home.s, ch: home.ch, text: c.text!),
      );
    }
    // The others name a note that exists: `remembered` an open one, `restore`
    // and `delete` an archived one (the book changes nothing otherwise).
    final note = ref.read(notesViewModelProvider).book.byId(id ?? '');
    final fits = note != null &&
        (c.op == NoteOp.remembered ? note.isOpen : note.isArchived);
    if (id == null || !fits) {
      return AgentResult(command: c, kind: AgentResultKind.failed);
    }
    switch (c.op) {
      case NoteOp.remembered:
        return _result(c, await notes.remembered(id));
      case NoteOp.restore:
        return _result(c, await notes.restore(id));
      case NoteOp.delete:
        return _result(c, await notes.delete(id));
      case NoteOp.add:
        return AgentResult(command: c, kind: AgentResultKind.failed);
    }
  }

  // -- erase and backup ---------------------------------------------------------

  Future<AgentResult> _erase(EraseCommand c) async {
    switch (c.what) {
      case AgentErase.log:
        final data = ref.read(memoProvider).data;
        await ref
            .read(memoProvider.notifier)
            .replaceWith(data.copyWith(events: const []));
      case AgentErase.reading:
        await ref.read(readingProvider.notifier).erase();
      case AgentErase.chats:
        await ref.read(chatListProvider.notifier).deleteAll();
    }
    return _done(c);
  }

  Future<AgentResult> _backup(BackupCommand c) async {
    final service = ref.read(driveBackupServiceProvider);
    final memo = ref.read(memoControllerProvider);
    final repo = ref.read(settingsRepositoryProvider);
    final notes = ref.read(notesControllerProvider);
    switch (c.op) {
      case BackupOp.now:
        await service.uploadBackupToDrive(
          memo: memo,
          settingsRepo: repo,
          notes: notes,
        );
        await ref
            .read(settingsViewModelProvider.notifier)
            .updateLastBackupTime(DateTime.now());
      case BackupOp.restore:
        await service.restoreFromDrive(
          memo: memo,
          settingsRepo: repo,
          notes: notes,
        );
        // The screens read the restored settings, log and notes.
        ref.invalidate(settingsViewModelProvider);
        ref.invalidate(memoProvider);
        unawaited(ref.read(notesViewModelProvider.notifier).refresh());
    }
    return _done(c);
  }

  // -- plan and undo ------------------------------------------------------------

  AgentResult _plan(PlanCommand c) {
    final planner = ref.read(planViewModelProvider.notifier);
    if (!planner.available) {
      return AgentResult(command: c, kind: AgentResultKind.unavailable);
    }
    // The plan arrives on Today whenever the planner's AI has answered.
    unawaited(planner.ask());
    return _done(c, route: AppRoutes.today);
  }

  Future<AgentResult> _undoLast(UndoCommand c, String currentId) async {
    AgentTurn? target;
    for (final t in state.turns) {
      if (t.id == currentId) break;
      if (t.canUndo) target = t;
    }
    if (target == null) {
      return AgentResult(command: c, kind: AgentResultKind.unavailable);
    }
    await undoTurn(target.id);
    return _done(c);
  }

  // -- helpers ------------------------------------------------------------------

  AgentTurn? _find(String id) {
    for (final t in state.turns) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _change(String id, AgentTurn Function(AgentTurn turn) change) {
    if (!ref.mounted) return;
    state = state.copyWith(
      turns: [
        for (final t in state.turns)
          if (t.id == id) change(t) else t,
      ],
    );
  }
}

final agentControllerProvider =
    NotifierProvider<AgentController, AgentChatState>(AgentController.new);
