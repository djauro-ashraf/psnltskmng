import 'package:personaltskmng/ask/models/ask_context.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';

/// Grounded prompt builder and parser for Ask AI.
final class AskPrompts {
  const AskPrompts._();

  static const String baseSystemPrompt = '''
You are a careful study assistant for a student of the Qur'an.

Ground rules:
- Base your answer on the text provided (the ayah, its translation, the tafsir passage). When something is not in it, say it comes from general knowledge and should be checked.
- Never quote, complete or invent Qur'anic Arabic from memory. Refer to ayahs only by reference in the form [2:255]; the app will show the real text.
- Do not invent hadith, narrators, scholars, reasons of revelation or quotations. If you are not sure, say so.
- When the tafsir gives several opinions, present them as the tafsir's opinions.
- Do not give legal rulings (fatwa). For rulings say a qualified scholar should be asked.
- Answer in {language}. Be clear and concise. Short paragraphs; a short list only when it helps.''';

  static const String freeChatPrompt = '''
You are a careful study assistant for a student of the Qur'an.

Ground rules:
- No ayah is attached to this chat. If the user asks about a specific ayah, suggest attaching it, or work only from its reference.
- Never quote, complete or invent Qur'anic Arabic from memory. Refer to ayahs only by reference in the form [2:255]; the app will show the real text.
- Do not invent hadith, narrators, scholars, reasons of revelation or quotations.
- Do not give legal rulings (fatwa).
- Answer in {language}. Be clear and concise.''';

  static String buildSystemPrompt({
    required String language,
    bool hasContext = true,
    bool shortLength = false,
  }) {
    final template = hasContext ? baseSystemPrompt : freeChatPrompt;
    final langText = language.trim().isEmpty ? 'the language of the question' : language;
    var result = template.replaceAll('{language}', langText);
    if (shortLength) {
      result += '\n- Keep answers especially brief and focused on the essentials.';
    }
    return result;
  }

  static String formatContextBlock(List<AskContext> contexts) {
    if (contexts.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('=== ATTACHED QURAN CONTEXT (GROUNDING) ===');
    for (var i = 0; i < contexts.length; i++) {
      final ctx = contexts[i];
      buffer.writeln('--- Context Item ${i + 1} ---');
      buffer.writeln('Ayah: ${ctx.ayah.key}');
      buffer.writeln('Arabic Text: ${ctx.arabic}');
      if (ctx.translation != null && ctx.translation!.isNotEmpty) {
        final author = ctx.translationAuthor != null
            ? ' (${ctx.translationAuthor})'
            : '';
        buffer.writeln('Translation$author:');
        buffer.writeln(ctx.translation);
      }
      if (ctx.words != null && ctx.words!.isNotEmpty) {
        buffer.writeln('Word-by-word gloss:');
        buffer.writeln(ctx.words!.join(' · '));
      }
      if (ctx.tafsirText != null && ctx.tafsirText!.isNotEmpty) {
        final title = ctx.tafsirTitle ?? 'Tafsir';
        final range = ctx.tafsirCovers != null
            ? ' (${_rangeText(ctx.tafsirCovers!)})'
            : '';
        buffer.writeln('$title$range:');
        buffer.writeln(ctx.tafsirText);
        if (ctx.isTafsirTruncated) {
          buffer.writeln('[Tafsir text truncated to fit length limit]');
        }
      }
      if (ctx.focusText != null && ctx.focusText!.isNotEmpty) {
        buffer.writeln('User highlighted focus text: "${ctx.focusText}"');
      }
      buffer.writeln();
    }
    buffer.writeln('=== END OF ATTACHED CONTEXT ===');
    return buffer.toString();
  }

  /// Finds `[2:255]` or `[114:6]` ayah references in model responses.
  static final RegExp referenceRegex = RegExp(r'\[(\d{1,3}):(\d{1,3})\]');

  static List<({AyahRef ref, int start, int end})> findReferences(String text) {
    final matches = referenceRegex.allMatches(text);
    final results = <({AyahRef ref, int start, int end})>[];
    for (final match in matches) {
      final surah = int.tryParse(match.group(1) ?? '');
      final ayah = int.tryParse(match.group(2) ?? '');
      if (surah != null && ayah != null) {
        if (surah >= 1 && surah <= 114) {
          final maxAyah = QuranDivisions.ayahCountOf(surah);
          if (ayah >= 1 && ayah <= maxAyah) {
            results.add((
              ref: AyahRef(surah, ayah),
              start: match.start,
              end: match.end,
            ));
          }
        }
      }
    }
    return results;
  }

  static String _rangeText(AyahRange range) {
    if (range.first == range.last) return range.first.key;
    if (range.first.surah == range.last.surah) {
      return '${range.first.key}–${range.last.ayah}';
    }
    return '${range.first.key}–${range.last.key}';
  }
}
