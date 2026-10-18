import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/ai/ai_planner.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/planning/planners/rule_based_planner.dart';
import 'package:personaltskmng/planning/validation/plan_validator.dart';

import '../planning/support.dart';

/// Scripted stand-in for an LLM: each call pops the next answer (a String, or
/// an [AiProviderException] to throw) and records the messages it was sent.
class FakeProvider implements AiProvider {
  FakeProvider(this.id, this.script);

  @override
  final String id;
  final List<Object> script;
  final List<List<AiMessage>> calls = [];

  @override
  Future<String> generateJson({
    required String system,
    required List<AiMessage> messages,
  }) async {
    calls.add(List.of(messages));
    final next = script.removeAt(0);
    if (next is AiProviderException) throw next;
    return next as String;
  }
}

const _validPlan =
    '{"ops":[{"op":"R","from":282,"to":322,"why":"all due tonight"}],"summary":"review everything"}';
const _ndReview = '{"ops":[{"op":"R","from":100,"to":105}]}';

void main() {
  const day1 = Day(1);
  final validator = PlanValidator(engine: testEngine, config: const PlanningConfig());
  const fallback = RuleBasedPlanner(engine: testEngine);

  AiPlanner planner(List<AiProvider> providers) =>
      AiPlanner(providers: providers, fallback: fallback, validator: validator);

  test('a valid first answer is accepted and attributed to its provider', () async {
    final gemini = FakeProvider('gemini', [_validPlan]);
    final groq = FakeProvider('groq', []);
    final result = await planner([gemini, groq]).plan(requestFor(freshQ(), day1, budget: 1200));

    expect(result.source, 'gemini');
    expect(result.ops.map((o) => o.label), ['R 282-322']);
    expect(result.rationale, 'review everything');
    expect(result.attempts.map((a) => a.outcome), ['accepted']);
    expect(groq.calls, isEmpty);
  });

  test('violations are sent back once, with the exact reason; the fixed answer wins', () async {
    final gemini = FakeProvider('gemini', [_ndReview, _validPlan]);
    final result = await planner([gemini]).plan(requestFor(freshQ(), day1, budget: 1200));

    expect(result.source, 'gemini');
    expect(result.attempts.map((a) => a.outcome), ['violations', 'accepted']);
    expect(gemini.calls, hasLength(2));
    final second = gemini.calls[1];
    expect(second.map((m) => m.role), [AiRole.user, AiRole.assistant, AiRole.user]);
    expect(second[1].text, _ndReview);
    expect(second[2].text, contains('op 1 (R 100-105)'));
    expect(second[2].text, contains('pageNotEligibleForR'));
  });

  test('unparseable output is re-asked too', () async {
    final gemini = FakeProvider('gemini', ['sorry, no JSON', _validPlan]);
    final result = await planner([gemini]).plan(requestFor(freshQ(), day1, budget: 1200));
    expect(result.source, 'gemini');
    expect(gemini.calls[1][2].text, contains('no JSON object'));
  });

  test('still wrong after the re-ask: next provider; provider error: next; all failed: offline plan', () async {
    final gemini = FakeProvider('gemini', [_ndReview, _ndReview]);
    final groq = FakeProvider('groq', [
      const AiProviderException(AiErrorKind.missingKey, 'No Groq API key stored'),
    ]);
    final result = await planner([gemini, groq]).plan(requestFor(freshQ(), day1, budget: 1200));

    expect(result.source, RuleBasedPlanner.sourceId);
    expect(result.ops.map((o) => o.label), ['M 323-327', 'R 282-322']);
    expect(result.attempts.map((a) => '${a.provider}:${a.outcome}'), [
      'gemini:violations',
      'gemini:violations',
      'groq:error',
    ]);
    expect(gemini.calls, hasLength(2), reason: 'exactly one re-ask');
    expect(groq.calls, hasLength(1));
  });

  test('the second provider takes over when the first gives up', () async {
    final gemini = FakeProvider('gemini', [_ndReview, _ndReview]);
    final groq = FakeProvider('groq', [_validPlan]);
    final result = await planner([gemini, groq]).plan(requestFor(freshQ(), day1, budget: 1200));
    expect(result.source, 'groq');
    expect(result.attempts.map((a) => a.outcome), ['violations', 'violations', 'accepted']);
  });

  test('a plan over the time ceiling is not accepted; the re-ask says how many pages fit', () async {
    final gemini = FakeProvider('gemini', [_validPlan, '{"ops":[{"op":"R","from":282,"to":282}]}']);
    final result = await planner([gemini]).plan(requestFor(freshQ(), day1, budget: 30));
    expect(gemini.calls[1][2].text, contains('at most 1 page'));
    expect(result.source, 'gemini');
    expect(result.ops.map((o) => o.label), ['R 282-282']);
  });

  test('with no providers at all it is simply the offline planner', () async {
    final result = await planner(const []).plan(requestFor(freshQ(), day1));
    expect(result.source, RuleBasedPlanner.sourceId);
  });

  test('the system prompt lists priorities from the config', () async {
    final gemini = FakeProvider('gemini', [_validPlan]);
    const swapped = PlanningConfig(
      priority: PriorityConfig(order: [WorkClass.workingSetR, WorkClass.expand]),
    );
    final request = requestFor(freshQ(), day1, budget: 1200, config: swapped);
    final captured = <String>[];
    final spy = _SystemSpy(gemini, captured);
    await AiPlanner(
      providers: [spy],
      fallback: fallback,
      validator: PlanValidator(engine: testEngine, config: swapped),
    ).plan(request);
    expect(captured.single, contains('1. workingSetR'));
    expect(captured.single, contains('2. expand'));
  });
}

class _SystemSpy implements AiProvider {
  _SystemSpy(this.inner, this.systems);

  final FakeProvider inner;
  final List<String> systems;

  @override
  String get id => inner.id;

  @override
  Future<String> generateJson({
    required String system,
    required List<AiMessage> messages,
  }) {
    systems.add(system);
    return inner.generateJson(system: system, messages: messages);
  }
}
