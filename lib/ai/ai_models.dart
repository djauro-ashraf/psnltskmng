/// What a model is good for, in a few words. The settings screen turns each one
/// into a short translated line, so this file stays plain Dart with no text.
enum AiModelNote {
  /// The newest and most capable model of the provider's free list.
  newest,

  /// The previous generation: fast and well balanced.
  balanced,

  /// A lightweight model for simple tasks.
  light,

  /// The largest open model: the strongest reasoning.
  largest,

  /// A smaller, faster sibling of the largest model.
  small,
}

/// One model the settings screen offers in its list.
final class AiModelInfo {
  const AiModelInfo(this.id, this.note, {this.recommended = false});

  /// The model id exactly as the provider's API expects it.
  final String id;

  final AiModelNote note;

  /// The clear first choice of its provider's list (at most one per provider).
  final bool recommended;
}

// The lists below are models a FREE account can call, as the providers
// document them. Checked on 2026-10-19 (Gemini, Groq) and 2026-11-25 (GitHub
// Models, OpenRouter) against:
//   Gemini: ai.google.dev/gemini-api/docs/pricing (free tier column) and
//           .../deprecations (gemini-3.5-flash is only routed to 3.6 Flash;
//           the 2.5 models are limited to users who already used them).
//   Groq:   console.groq.com/docs/models and .../rate-limits (the free plan
//           limits table; Llama 3.x is listed there as Enterprise only, and
//           Qwen3.8-27B is a preview model).
//   GitHub: docs.github.com/en/github-models/use-github-models/
//           prototyping-with-ai-models (the rate limits table: low models 15
//           requests a minute and 150 a day, high models 10 and 50, 8,000
//           tokens in and 4,000 out per request; the gpt-5 and o-series are
//           for the paid Copilot plans only).
//   OpenRouter: openrouter.ai/docs/api-reference/limits (every ':free' model
//           shares 20 requests a minute and 50 a day, 1,000 a day once $10
//           were ever bought) and the free list of the day. Free ids are
//           retired without notice: the model field takes any text.
// The lists are a convenience, not a gate: the model field still takes any
// text, so a model missing here (or added by the provider later) can be typed.

/// Gemini models with a free tier, best first.
const List<AiModelInfo> geminiModels = [
  AiModelInfo('gemini-3.8-flash', AiModelNote.newest, recommended: true),
  AiModelInfo('gemini-3.6-flash', AiModelNote.balanced),
  AiModelInfo('gemini-3.5-flash-lite', AiModelNote.light),
];

/// Groq models on the free plan, best first.
const List<AiModelInfo> groqModels = [
  AiModelInfo('openai/gpt-oss-120b', AiModelNote.largest, recommended: true),
  AiModelInfo('openai/gpt-oss-20b', AiModelNote.small),
];

/// GitHub Models a free account can call, best first. The mini is the clear
/// first choice: it has three times the daily requests of the full model.
const List<AiModelInfo> githubModels = [
  AiModelInfo('openai/gpt-4.1-mini', AiModelNote.balanced, recommended: true),
  AiModelInfo('openai/gpt-4.1', AiModelNote.largest),
  AiModelInfo('openai/gpt-4.1-nano', AiModelNote.light),
];

/// OpenRouter free models whose hosts keep no prompts for training, best first.
const List<AiModelInfo> openRouterModels = [
  AiModelInfo(
    'google/gemma-4-31b-it:free',
    AiModelNote.balanced,
    recommended: true,
  ),
  AiModelInfo('google/gemma-4-26b-a4b-it:free', AiModelNote.small),
];
