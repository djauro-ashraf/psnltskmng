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
// document them. Checked on 2026-10-19 against:
//   Gemini: ai.google.dev/gemini-api/docs/pricing (free tier column) and
//           .../deprecations (gemini-3.5-flash is only routed to 3.6 Flash;
//           the 2.5 models are limited to users who already used them).
//   Groq:   console.groq.com/docs/models and .../rate-limits (the free plan
//           limits table; Llama 3.x is listed there as Enterprise only, and
//           Qwen3.8-27B is a preview model).
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
