import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/ask/models/ask_context.dart';
import 'package:personaltskmng/ask/prompts/ask_prompts.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';

void main() {
  group('AskPrompts.buildSystemPrompt', () {
    test('substitutes language and includes guidelines', () {
      final prompt = AskPrompts.buildSystemPrompt(
        language: 'English',
        hasContext: true,
        shortLength: false,
      );
      expect(prompt, contains('Answer in English.'));
      expect(prompt, contains("student of the Qur'an"));
      expect(prompt, contains('Base your answer on the text provided'));
    });

    test('supports free chat without context expectation', () {
      final prompt = AskPrompts.buildSystemPrompt(
        language: 'French',
        hasContext: false,
        shortLength: true,
      );
      expect(prompt, contains('Answer in French.'));
      expect(prompt, contains('Keep answers especially brief'));
      expect(prompt, contains('No ayah is attached to this chat.'));
    });
  });

  group('AskPrompts.formatContextBlock', () {
    test('returns empty string when no contexts provided', () {
      expect(AskPrompts.formatContextBlock([]), isEmpty);
    });

    test('formats AskContext correctly with translation and tafsir', () {
      final ctx = [
        AskContext(
          ayah: const AyahRef(2, 255),
          arabic: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ',
          translation: 'Allah! There is no deity except Him...',
          translationAuthor: 'Saheeh',
          words: const ['Allah', 'no', 'deity'],
          tafsirTitle: 'Ibn Kathir',
          tafsirCovers: AyahRange(const AyahRef(2, 255), const AyahRef(2, 255)),
          tafsirText: 'This is the greatest ayah in the Book of Allah.',
          focusText: 'no deity',
        ),
      ];
      final formatted = AskPrompts.formatContextBlock(ctx);
      expect(formatted, contains('=== ATTACHED QURAN CONTEXT (GROUNDING) ==='));
      expect(formatted, contains('Ayah: 2:255'));
      expect(formatted, contains('Arabic Text: اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ'));
      expect(formatted, contains('Translation (Saheeh):'));
      expect(formatted, contains('Allah! There is no deity except Him...'));
      expect(formatted, contains('Word-by-word gloss:'));
      expect(formatted, contains('Allah · no · deity'));
      expect(formatted, contains('Ibn Kathir (2:255):'));
      expect(formatted, contains('This is the greatest ayah in the Book of Allah.'));
      expect(formatted, contains('User highlighted focus text: "no deity"'));
      expect(formatted, contains('=== END OF ATTACHED CONTEXT ==='));
    });
  });

  group('AskPrompts reference parsing', () {
    test('findReferences finds ayah references in bounds', () {
      const text = 'See [2:255] and also read [1:1] for context, but not [999:1] or [2:999].';
      final refs = AskPrompts.findReferences(text);
      expect(refs.length, 2);
      expect(refs[0].ref.surah, 2);
      expect(refs[0].ref.ayah, 255);
      expect(refs[0].start, text.indexOf('[2:255]'));

      expect(refs[1].ref.surah, 1);
      expect(refs[1].ref.ayah, 1);
      expect(refs[1].start, text.indexOf('[1:1]'));
    });

    test('findReferences ignores invalid surah numbers', () {
      const text = '[115:1] is out of range, [0:1] is out of range, [2:300] is out of range.';
      final refs = AskPrompts.findReferences(text);
      expect(refs, isEmpty);
    });
  });
}
