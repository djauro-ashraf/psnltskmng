import 'dart:math' as math;

import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/plan_parser.dart';
import 'package:personaltskmng/ai/prompt_builder.dart';
import 'package:personaltskmng/planning/models/minutes.dart';
import 'package:personaltskmng/planning/models/plan_op.dart';
import 'package:personaltskmng/planning/models/plan_violation.dart';
import 'package:personaltskmng/planning/planners/planner.dart';
import 'package:personaltskmng/planning/validation/plan_validator.dart';

/// Tries each provider in order (Gemini, then Groq, ...). For each: ask,
/// parse, dry-run every op through the validator. If anything is wrong, ask
/// the SAME provider once more with the exact violations; if it is still
/// wrong, or the provider errors, move on. If every provider fails, use
/// [fallback] (the offline rule-based planner). The AI never sees or changes
/// a Q: it returns advice that has already passed the real rules engine.
///
/// Its validation uses the silent minutes band (RULES.md, "Minutes band for AI
/// plans"): a higher minutes ceiling and a lower limit. The AI is never told
/// about the band.
final class AiPlanner implements Planner {
  const AiPlanner({
    required this.providers,
    required this.fallback,
    required this.validator,
    this.prompts = const PromptBuilder(),
    this.parser = const PlanParser(),
    this.maxReasks = 1,
  });

  final List<AiProvider> providers;
  final Planner fallback;
  final PlanValidator validator;
  final PromptBuilder prompts;
  final PlanParser parser;

  /// Re-asks per provider after the first answer had violations.
  final int maxReasks;

  @override
  Future<PlanCandidate> plan(PlanRequest request) async {
    final traces = <AttemptTrace>[];
    // The offline plan is computed ONCE per request: it is the reference of
    // the lower minutes limit and, if every provider fails, the answer.
    final offline = await fallback.plan(request);
    final workload = request.config.workload;
    final band = MinutesBand(highFactor: workload.aiHighFactor);
    final facts = request.facts;
    final availableMinutes = math.max(
      0.0,
      facts.dayBudgetMinutes - facts.spentMinutes,
    );
    final offlineMinutes = validator
        .validate(
          q: request.q,
          day: request.day,
          proposed: offline.ops,
          facts: facts,
        )
        .minutes;
    final reference = math.min(availableMinutes, offlineMinutes);
    final floorMinutes = workload.aiLowFactor * reference;
    final system = prompts.system(request.config, request.constraints);
    final first = AiMessage(AiRole.user, prompts.user(request.snapshot));

    for (final provider in providers) {
      final messages = <AiMessage>[first];
      var attempt = 1;
      while (true) {
        String? raw;
        try {
          raw = await provider.generateJson(
            system: system,
            messages: List.of(messages),
          );
        } on AiProviderException catch (e) {
          traces.add(
            AttemptTrace(
              provider: provider.id,
              attempt: attempt,
              outcome: 'error',
              error: '${e.kind.name}: ${e.message}',
            ),
          );
        }
        if (raw == null) break;

        final parsed = parser.parse(raw);
        List<PlanViolation> issues;
        List<PlanOp>? accepted;
        if (parsed.failed) {
          issues = parsed.issues;
        } else {
          final validation = validator.validate(
            q: request.q,
            day: request.day,
            proposed: parsed.ops,
            facts: request.facts,
            band: band,
          );
          issues = [...parsed.issues, ...validation.violations];
          accepted = validation.accepted;
          // Lower limit (silent): only when nothing else is wrong. The text
          // names the minutes the AI already knows, not the factors.
          if (issues.isEmpty &&
              reference > 0 &&
              validation.minutes < floorMinutes - 1e-9) {
            issues = [
              PlanViolation(
                kind: ViolationKind.underBudget,
                message:
                    'Your plan uses only ${fmtMinutes(validation.minutes)} min '
                    'of the ${fmtMinutes(availableMinutes)} min available '
                    'today. Add work that fits within the limits listed.',
              ),
            ];
          }
        }

        if (issues.isEmpty && accepted != null) {
          traces.add(
            AttemptTrace(
              provider: provider.id,
              attempt: attempt,
              outcome: 'accepted',
              raw: raw,
            ),
          );
          return PlanCandidate(
            ops: accepted,
            source: provider.id,
            rationale: parsed.summary,
            attempts: traces,
          );
        }

        traces.add(
          AttemptTrace(
            provider: provider.id,
            attempt: attempt,
            outcome: 'violations',
            violations: [for (final v in issues) v.toPromptLine()],
            raw: raw,
          ),
        );
        if (attempt > maxReasks) break;
        messages
          ..add(AiMessage(AiRole.assistant, raw))
          ..add(AiMessage(AiRole.user, prompts.repair(issues)));
        attempt++;
      }
    }

    return PlanCandidate(
      ops: offline.ops,
      source: offline.source,
      rationale: offline.rationale,
      attempts: [...traces, ...offline.attempts],
    );
  }
}
