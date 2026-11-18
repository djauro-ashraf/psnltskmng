import 'package:personaltskmng/ask/models/ask_context.dart';

enum AskPresetId {
  explainSimply,
  explainDeeper,
  simplifyTafsir,
  wordsGrammar,
  lessons,
  helpRemember,
}

final class AskPreset {
  const AskPreset({
    required this.id,
    required this.defaultLabel,
    required this.instruction,
    this.needsTafsir = false,
    this.needsWords = false,
  });

  final AskPresetId id;
  final String defaultLabel;
  final String instruction;
  final bool needsTafsir;
  final bool needsWords;

  /// Whether this preset is usable given the attached context.
  bool isAvailable(AskContext? context) {
    if (context == null) return false;
    if (needsTafsir && (context.tafsirText == null || context.tafsirText!.isEmpty)) {
      return false;
    }
    if (needsWords && (context.words == null || context.words!.isEmpty)) {
      return false;
    }
    return true;
  }

  static const List<AskPreset> all = [
    AskPreset(
      id: AskPresetId.explainSimply,
      defaultLabel: 'Explain simply',
      instruction: 'Explain this ayah in simple words for a beginner.',
    ),
    AskPreset(
      id: AskPresetId.explainDeeper,
      defaultLabel: 'Explain deeper',
      instruction:
          'Explain in more depth: main ideas, key words, and how it connects to the ayahs around it.',
    ),
    AskPreset(
      id: AskPresetId.simplifyTafsir,
      defaultLabel: 'Simplify tafsir',
      instruction:
          'Rewrite this tafsir passage in simple language, keeping every main point. Present opinions as the scholar’s.',
      needsTafsir: true,
    ),
    AskPreset(
      id: AskPresetId.wordsGrammar,
      defaultLabel: 'Words & grammar',
      instruction:
          'Explain the key words and any grammatical nuances that affect the meaning.',
      needsWords: true,
    ),
    AskPreset(
      id: AskPresetId.lessons,
      defaultLabel: 'Lessons',
      instruction:
          'Give practical lessons a student can take from this text, tied directly to the verse.',
    ),
    AskPreset(
      id: AskPresetId.helpRemember,
      defaultLabel: 'Help me remember',
      instruction:
          'Provide a memorable way to remember this ayah and how it connects to the ayahs before and after it.',
    ),
  ];
}

/// A one-tap request after an answer. The chip says it in the reader's language
/// (the screen's translation); [instruction] is what goes to the model.
enum AskFollowUp {
  shorter('Make the previous answer shorter and more concise.'),
  moreDetail('Explain the previous answer in more depth and detail.'),
  example('Give a clear real-life example to illustrate this.'),
  french('Explain the previous answer in French.'),
  arabic('Explain the previous answer in Arabic.');

  const AskFollowUp(this.instruction);

  final String instruction;
}
