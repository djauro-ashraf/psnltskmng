import 'dart:convert';

import 'package:personaltskmng/agent/routing/agent_module.dart';
import 'package:personaltskmng/agent/routing/agent_triggers.dart';

/// How the modules of a request were chosen.
enum RouteVia {
  /// By the words of the request (no network, no cost).
  rules,

  /// The request answers the one before it ("yes", "the second"): the same
  /// modules again.
  sticky,

  /// By a small model that was asked, because the words said nothing.
  triage,

  /// Nobody could say: the commonest modules.
  fallback,

  /// The AI asked for them itself (`need`), after it was taught too little.
  asked,

  /// Routing is off: the whole language.
  all,
}

/// The modules chosen for one request, and how.
final class RouteDecision {
  const RouteDecision(this.modules, this.via, {this.needsTriage = false});

  final Set<AgentModule> modules;
  final RouteVia via;

  /// The rules could not place the request (no word of any module, or a change
  /// without a hint of what): a small model may be asked. [modules] is then
  /// what the rules did find, which stands if the small model cannot be asked.
  final bool needsTriage;
}

/// Chooses what the AI is taught for one request: the cheapest way that is
/// right, and a way back when it is not.
///
///  1. **The conversation.** A short reply to the previous turn ("yes",
///     "the second one") needs what that turn needed.
///  2. **The rules.** The words of the request, in three languages
///     ([AgentTriggers]). Right for the plain requests, which are most.
///  3. **A small model.** When the rules find nothing, a model of the light
///     kind is asked, with a prompt of a few lines, which modules fit
///     ([triageSystem], [parseTriage]). It does not need to be wise: it only
///     sorts.
///  4. **The way back.** A request routed wrongly is not a failure: the AI is
///     told what it was not taught and may answer `{"need": [...]}`
///     ([needOf]); the app teaches it and asks once more.
///
/// A router that failed (no model, no answer) is not an error: the commonest
/// modules are used ([AgentModules.fallback]). Pure Dart.
abstract final class AgentRouter {
  /// A reply this short, with no word of its own, answers the previous turn.
  static const int followUpLength = 40;

  /// The rules and the conversation. [previous] is what the last turn was
  /// taught (empty at the start of a conversation).
  static RouteDecision decide(
    String text, {
    Set<AgentModule> previous = const {},
  }) {
    final clean = text.trim();
    final scan = AgentTriggers.scan(clean);
    if (scan.hits.isEmpty) {
      if (previous.isNotEmpty && clean.length <= followUpLength) {
        return RouteDecision(previous, RouteVia.sticky);
      }
      // Too short to be worth a question to a model ("hello", "ok").
      return RouteDecision(
        const {},
        RouteVia.rules,
        needsTriage: clean.length >= 6,
      );
    }
    final ranked = scan.hits.entries.toList()
      ..sort((a, b) {
        final byScore = b.value.compareTo(a.value);
        return byScore != 0 ? byScore : a.key.index.compareTo(b.key.index);
      });
    return RouteDecision(
      {for (final entry in ranked.take(AgentModules.most)) entry.key},
      RouteVia.rules,
      // "turn the plan off": the words are about the plan, the change is of
      // a setting nobody named.
      needsTriage: scan.vagueChange,
    );
  }

  // -- the small model ---------------------------------------------------------

  /// What the small model is told. Short on purpose: it is paid for on every
  /// request it is asked about. It says "JSON" (the JSON mode of Groq wants the
  /// word).
  static final String triageSystem = _triageSystem();

  static String _triageSystem() {
    final list = [
      for (final module in AgentModule.values) '${module.id}: ${module.about}',
    ].join('\n');
    return '''
You sort requests for a Quran memorisation app. The user writes in English, French or Arabic. Say which parts of the app the request needs. Reply with ONLY a JSON object: {"modules": ["<name>", ...]}. Use 1 to 3 names from this list, the fewest that fit. Use [] when the request is small talk or needs none of them.
$list''';
  }

  /// The one message the small model answers.
  static String triageMessage(String text, {Set<AgentModule> previous = const {}}) =>
      jsonEncode({
        'request': text,
        if (previous.isNotEmpty) 'previous': [for (final m in previous) m.id],
      });

  /// The modules the small model named, or null when its answer is not usable.
  /// Names it made up are left out; an empty list is an answer (none needed).
  static Set<AgentModule>? parseTriage(String raw) {
    final object = _object(raw);
    if (object == null) return null;
    final names = object['modules'];
    if (names is! List) return null;
    return {
      for (final name in names)
        if (name is String) ?AgentModule.byId(name),
    };
  }

  // -- the way back ------------------------------------------------------------

  /// The modules the AI asked for (`{"need": ["settings.ai"]}`), or an empty set
  /// when it asked for none. Only an answer with no instruction in it counts as
  /// asking.
  static Set<AgentModule> needOf(String raw) {
    final object = _object(raw);
    if (object == null) return const {};
    final actions = object['actions'];
    if (actions is List && actions.isNotEmpty) return const {};
    final need = object['need'];
    final names = need is List ? need : (need is String ? [need] : const []);
    return {
      for (final name in names)
        if (name is String) ?AgentModule.byId(name),
    };
  }

  /// The JSON object in [raw], through a fence or a word around it.
  static Map<String, Object?>? _object(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(raw.substring(start, end + 1));
      return decoded is Map<String, Object?> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
