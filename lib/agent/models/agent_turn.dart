import 'package:personaltskmng/agent/models/agent_command.dart';
import 'package:personaltskmng/ai/ai_provider.dart';

/// Where one turn of the conversation stands.
enum AgentPhase {
  /// The request is with the AI.
  thinking,

  /// The AI answered and the agent is set to ask first: nothing was done yet.
  pending,

  /// The instructions are being carried out.
  running,

  /// Everything was carried out (some steps may have failed or not fitted).
  done,

  /// The user said no to what was pending, or wrote something else instead.
  cancelled,

  /// The AI could not be asked or its answer could not be used.
  failed,
}

/// Why a turn failed.
enum AgentFailure {
  /// The agent is switched off (or has no AI behind it).
  noAi,

  /// The provider answered with an error (see [AgentTurn.errorKind]).
  provider,

  /// The answer was not in the app's language at all.
  unreadable,

  /// Anything else.
  other,
}

/// How one instruction ended.
enum AgentResultKind {
  /// Carried out.
  done,

  /// A log whose range did not fit the memorise / review rule: nothing written.
  nothingFits,

  /// It was tried and did not work.
  failed,

  /// It cannot be done right now (no planner AI, nothing to undo).
  unavailable,
}

/// What the app did with one instruction. Structured, not text: the screen
/// words it in the language of the app, the AI is told it in English.
final class AgentResult {
  const AgentResult({
    required this.command,
    required this.kind,
    this.ayahs = 0,
    this.skipped = 0,
    this.group,
    this.route,
  });

  final AgentCommand command;
  final AgentResultKind kind;

  /// For a log: ayahs written, and ayahs left out by the memorise / review rule.
  final int ayahs;
  final int skipped;

  /// For a log that wrote something: its group (what Undo removes).
  final int? group;

  /// Where the app should go afterwards (an `open`, or a `plan`).
  final String? route;

  bool get ok => kind == AgentResultKind.done;
}

/// One request of the user with the AI's answer and what the app did.
/// Immutable; a new one replaces it at every step.
final class AgentTurn {
  const AgentTurn({
    required this.id,
    required this.userText,
    required this.phase,
    this.say = '',
    this.commands = const [],
    this.results = const [],
    this.dropped = 0,
    this.reply,
    this.failure,
    this.error,
    this.errorKind,
    this.undone = false,
  });

  final String id;
  final String userText;
  final AgentPhase phase;

  /// What the AI said (never what the app did).
  final String say;

  /// The instructions the app understood.
  final List<AgentCommand> commands;

  /// What happened to each, once they ran (same order as [commands]).
  final List<AgentResult> results;

  /// Instructions the app could not read and left out.
  final int dropped;

  /// The AI's raw answer, kept to give it back to the AI as history.
  final String? reply;

  final AgentFailure? failure;

  /// The provider's own message for [AgentFailure.provider] (never a key).
  final String? error;
  final AiErrorKind? errorKind;

  /// True once the logs of this turn were undone.
  final bool undone;

  /// The logs this turn wrote (an undo removes them all).
  List<int> get groups => [
    for (final r in results)
      if (r.group != null) r.group!,
  ];

  bool get canUndo => !undone && groups.isNotEmpty;

  AgentTurn copyWith({
    AgentPhase? phase,
    String? say,
    List<AgentCommand>? commands,
    List<AgentResult>? results,
    int? dropped,
    String? reply,
    AgentFailure? failure,
    String? error,
    AiErrorKind? errorKind,
    bool? undone,
  }) => AgentTurn(
    id: id,
    userText: userText,
    phase: phase ?? this.phase,
    say: say ?? this.say,
    commands: commands ?? this.commands,
    results: results ?? this.results,
    dropped: dropped ?? this.dropped,
    reply: reply ?? this.reply,
    failure: failure ?? this.failure,
    error: error ?? this.error,
    errorKind: errorKind ?? this.errorKind,
    undone: undone ?? this.undone,
  );
}

/// The whole conversation, and the place the app has to go to next.
final class AgentChatState {
  const AgentChatState({this.turns = const [], this.route});

  final List<AgentTurn> turns;

  /// A path the screen must go to (an `open` was carried out); the screen takes
  /// it and clears it.
  final String? route;

  /// A request is being answered or carried out: no second one meanwhile.
  bool get busy =>
      turns.isNotEmpty &&
      (turns.last.phase == AgentPhase.thinking ||
          turns.last.phase == AgentPhase.running);

  AgentChatState copyWith({List<AgentTurn>? turns}) =>
      AgentChatState(turns: turns ?? this.turns, route: route);

  AgentChatState withRoute(String? route) =>
      AgentChatState(turns: turns, route: route);
}
