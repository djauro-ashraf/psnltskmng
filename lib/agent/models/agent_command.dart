import 'package:personaltskmng/agent/models/agent_catalog.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/span.dart';

/// How much a command can hurt, which decides who must say yes.
enum AgentRisk {
  /// Looks or asks only (open a screen, ask for a plan, choose the day Today
  /// logs for, undo the agent's own last log): no tap needed.
  free,

  /// Changes the user's data or settings and can be put back: shown first when
  /// the agent is set to "ask before doing", done at once otherwise.
  change,

  /// Cannot be put back (erasing the log, deleting a note, restoring a backup
  /// over everything): ALWAYS shown first, whatever the approval mode. The
  /// user's tap is the one thing the AI can never replace.
  destructive,
}

/// One instruction in the app's language: what the AI may ask the app to do.
/// The list is closed. Anything the AI writes that is not one of these (or is
/// one with values the app cannot use) is dropped by `AgentParser`, never
/// guessed. Pure Dart.
sealed class AgentCommand {
  const AgentCommand();

  AgentRisk get risk;

  /// True when it changes data or settings (so "ask before doing" shows it).
  bool get changesData => risk != AgentRisk.free;

  /// True when it must be shown and confirmed even when the agent acts at once.
  bool get alwaysAsk => risk == AgentRisk.destructive;
}

/// "I memorised / reviewed this, on this day": one line in the log, written by
/// the same rule as every other way of logging.
final class LogCommand extends AgentCommand {
  const LogCommand({
    required this.kind,
    required this.span,
    required this.day,
    required this.rangeText,
  });

  final MemoKind kind;
  final Span span;

  /// Already worked out (today, yesterday or a date), never in the future.
  final Day day;

  /// What the AI wrote for the range ("ch 5", "p 12-15"), for display.
  final String rangeText;

  @override
  AgentRisk get risk => AgentRisk.change;
}

/// Chooses the day Today logs for (what the calendar button of Today does).
/// [day] null is today, so it follows midnight.
final class LogDayCommand extends AgentCommand {
  const LogDayCommand(this.day);

  final Day? day;

  @override
  AgentRisk get risk => AgentRisk.free;
}

/// The screens the agent can open.
enum AgentScreen {
  today,
  browse,
  overview,
  settings,
  quranData,

  /// The list of the assistant's chats.
  chats,

  /// The numbers behind the statuses, and the guide that explains them.
  statusRules,
  statusGuide,

  /// The user's own partitions.
  partitions,
}

/// A place the agent can take the user to.
sealed class AgentPlace {
  const AgentPlace();
}

final class ScreenPlace extends AgentPlace {
  const ScreenPlace(this.screen);

  final AgentScreen screen;
}

final class PagePlace extends AgentPlace {
  const PagePlace(this.page);

  final int page;
}

final class SurahPlace extends AgentPlace {
  const SurahPlace(this.surah);

  final int surah;
}

final class ChPlace extends AgentPlace {
  const ChPlace(this.ch);

  final int ch;
}

final class JuzPlace extends AgentPlace {
  const JuzPlace(this.juz);

  final int juz;
}

/// A surah inside a ch, limited to its pages.
final class PartPlace extends AgentPlace {
  const PartPlace(this.surah, this.ch);

  final int surah;
  final int ch;
}

/// An ayah in the reader; [view] is `mushaf`, `words` or `details` when given.
final class AyahPlace extends AgentPlace {
  const AyahPlace(this.ayah, {this.view});

  final AyahRef ayah;
  final String? view;
}

/// A run of pages.
final class RangePlace extends AgentPlace {
  const RangePlace(this.from, this.to);

  final int from;
  final int to;
}

/// The tafsir of an ayah, full screen.
final class TafsirPlace extends AgentPlace {
  const TafsirPlace(this.ayah);

  final AyahRef ayah;
}

/// A new assistant chat, with an ayah attached and a question put in the box
/// (the user still presses send).
final class AskPlace extends AgentPlace {
  const AskPlace({this.ayah, this.prompt});

  final AyahRef? ayah;
  final String? prompt;
}

/// Goes to [place].
final class OpenCommand extends AgentCommand {
  const OpenCommand(this.place);

  final AgentPlace place;

  @override
  AgentRisk get risk => AgentRisk.free;
}

/// Changes one setting of [AgentCatalog]. [value] is already checked and
/// normalised by [AgentSettingSpec.normalise] (a bool, an int, a word, text).
final class SetCommand extends AgentCommand {
  const SetCommand(this.spec, this.value);

  final AgentSettingSpec spec;
  final Object value;

  @override
  AgentRisk get risk => AgentRisk.change;
}

/// Creates one of the user's own partitions, or replaces one when [id] is given.
/// [starts] are ayah places (the first piece always begins at the start of the
/// Quran). Nothing in the log refers to a partition, so it changes only how
/// things are grouped.
final class PartitionSaveCommand extends AgentCommand {
  const PartitionSaveCommand({
    required this.name,
    required this.unit,
    required this.starts,
    this.id,
  });

  final String? id;
  final String name;
  final String unit;
  final List<int> starts;

  @override
  AgentRisk get risk => AgentRisk.change;
}

final class PartitionDeleteCommand extends AgentCommand {
  const PartitionDeleteCommand(this.id);

  final String id;

  @override
  AgentRisk get risk => AgentRisk.change;
}

enum NoteOp {
  /// A new note on a page.
  add,

  /// "I remembered" on a note.
  remembered,

  /// An archived note becomes open again.
  restore,

  /// Deletes a note for good.
  delete,
}

/// Does one thing to the notes. [page], [text] (and optionally [s] and [ch],
/// the surah and ch the note is filed under) for `add`; [id] for the rest.
final class NoteCommand extends AgentCommand {
  const NoteCommand(
    this.op, {
    this.id,
    this.page,
    this.text,
    this.s,
    this.ch,
  });

  final NoteOp op;
  final String? id;
  final int? page;
  final String? text;
  final int? s;
  final int? ch;

  @override
  AgentRisk get risk =>
      op == NoteOp.delete ? AgentRisk.destructive : AgentRisk.change;
}

enum AgentErase {
  /// The whole log (settings, partitions and notes stay).
  log,

  /// The time-on-page evidence of the reader.
  reading,

  /// Every assistant chat.
  chats,
}

/// Erases something for good. Always shown and confirmed first.
final class EraseCommand extends AgentCommand {
  const EraseCommand(this.what);

  final AgentErase what;

  @override
  AgentRisk get risk => AgentRisk.destructive;
}

enum BackupOp {
  /// Writes a backup to the user's Google Drive (it must be connected).
  now,

  /// Replaces what is on this device with the backup on Drive.
  restore,
}

final class BackupCommand extends AgentCommand {
  const BackupCommand(this.op);

  final BackupOp op;

  @override
  AgentRisk get risk =>
      op == BackupOp.restore ? AgentRisk.destructive : AgentRisk.change;
}

/// Asks the user's own AI planner for today's plan (the Today screen shows it).
final class PlanCommand extends AgentCommand {
  const PlanCommand();

  @override
  AgentRisk get risk => AgentRisk.free;
}

/// Undoes the last thing the agent logged.
final class UndoCommand extends AgentCommand {
  const UndoCommand();

  @override
  AgentRisk get risk => AgentRisk.free;
}
