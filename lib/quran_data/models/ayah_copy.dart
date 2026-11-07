import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/footnote_text.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';

/// Which parts of an ayah can be included when copying.
enum CopyPart { arabic, translation, words, tafsir }

/// The parts and reference flag chosen for copying.
final class CopyRecipe {
  const CopyRecipe({
    required this.parts,
    this.reference = true,
  });

  final Set<CopyPart> parts;
  final bool reference;

  /// Preset: only the Arabic text with reference.
  static const arabicOnly = CopyRecipe(
    parts: {CopyPart.arabic},
    reference: true,
  );

  /// Preset: Arabic text and translation with reference.
  static const arabicAndTranslation = CopyRecipe(
    parts: {CopyPart.arabic, CopyPart.translation},
    reference: true,
  );

  /// Preset: Arabic, translation, word-by-word glosses, and tafsir.
  static const everything = CopyRecipe(
    parts: {
      CopyPart.arabic,
      CopyPart.translation,
      CopyPart.words,
      CopyPart.tafsir,
    },
    reference: true,
  );

  String encode() {
    final partsStr = parts.map((e) => e.name).join(',');
    return reference ? partsStr : '$partsStr;noref';
  }

  static CopyRecipe decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return CopyRecipe.arabicAndTranslation;
    }
    final hasNoRef = raw.contains(';noref');
    final cleaned = raw.replaceAll(';noref', '').trim();
    final partNames = cleaned
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    final parts = <CopyPart>{};
    for (final name in partNames) {
      for (final val in CopyPart.values) {
        if (val.name == name) {
          parts.add(val);
        }
      }
    }
    return CopyRecipe(
      parts: parts.isEmpty ? {CopyPart.arabic, CopyPart.translation} : parts,
      reference: !hasNoRef,
    );
  }

  CopyRecipe copyWith({
    Set<CopyPart>? parts,
    bool? reference,
  }) {
    return CopyRecipe(
      parts: parts ?? this.parts,
      reference: reference ?? this.reference,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CopyRecipe &&
          reference == other.reference &&
          parts.length == other.parts.length &&
          parts.containsAll(other.parts);

  @override
  int get hashCode => Object.hash(reference, Object.hashAll(parts));
}

/// The loaded data for one ayah ready for copying. The builder does no I/O.
final class AyahCopyInput {
  const AyahCopyInput({
    required this.ayah,
    this.translation,
    this.tafsir,
  });

  final AyahWords ayah;
  final ({String text, String? author})? translation;
  final ({AyahRange covers, String title, List<String> paragraphs})? tafsir;
}

final class AyahCopyResult {
  const AyahCopyResult({required this.text, this.isTruncated = false});

  final String text;
  final bool isTruncated;
}

abstract final class AiCopyInstructions {
  static const String explain =
      'Explain this ayah in simple words for a beginner.';
  static const String simplifyTafsir =
      'Rewrite this tafsir in simple language, keeping all main points.';
  static const String defaultCustom =
      'Explain the key lessons and context of this ayah.';
}

/// Pure Dart builder that formats Quran verses, translations, word glosses,
/// and tafsir into clean, copyable text.
abstract final class AyahCopy {
  static const int maxCharacters = 100000;

  static AyahCopyResult build(
    List<AyahCopyInput> items,
    CopyRecipe recipe, {
    String? aiInstruction,
  }) {
    if (items.isEmpty) return const AyahCopyResult(text: '');

    final buffer = StringBuffer();

    if (aiInstruction != null && aiInstruction.trim().isNotEmpty) {
      buffer.writeln(aiInstruction.trim());
      buffer.writeln();
    }

    final hasArabic = recipe.parts.contains(CopyPart.arabic);
    final hasTranslation = recipe.parts.contains(CopyPart.translation);
    final hasWords = recipe.parts.contains(CopyPart.words);
    final hasTafsir = recipe.parts.contains(CopyPart.tafsir);

    var sectionCount = 0;

    // 1. Arabic section
    if (hasArabic) {
      final arabicLines = <String>[];
      for (final item in items) {
        final refStr = recipe.reference ? ' (${item.ayah.key})' : '';
        arabicLines.add('${item.ayah.arabic}$refStr');
      }
      if (arabicLines.isNotEmpty) {
        if (sectionCount > 0) buffer.writeln();
        buffer.writeln(arabicLines.join('\n'));
        sectionCount++;
      }
    }

    // 2. Translation section
    if (hasTranslation) {
      final translationLines = <String>[];
      String? author;
      for (final item in items) {
        final tr = item.translation;
        if (tr != null && tr.text.trim().isNotEmpty) {
          author ??= tr.author;
          final cleanText = FootnoteText.plain(tr.text).trim();
          final refStr = (recipe.reference && (!hasArabic || items.length > 1))
              ? '(${item.ayah.key}) '
              : '';
          translationLines.add('$refStr$cleanText');
        }
      }
      if (translationLines.isNotEmpty) {
        if (sectionCount > 0) buffer.writeln();
        final header = author != null && author.trim().isNotEmpty
            ? 'Translation — $author'
            : 'Translation';
        buffer.writeln(header);
        buffer.writeln(translationLines.join('\n'));
        sectionCount++;
      }
    }

    // 3. Word by word section
    if (hasWords) {
      final wordBlocks = <String>[];
      for (final item in items) {
        final words = item.ayah.words;
        if (words.isNotEmpty) {
          final wordsStr = words.map((w) {
            final gloss = w.gloss.trim();
            return gloss.isNotEmpty ? '${w.arabic} = $gloss' : w.arabic;
          }).join(' · ');
          final label = items.length > 1 && recipe.reference
              ? 'Word by word (${item.ayah.key})'
              : 'Word by word';
          wordBlocks.add('$label\n$wordsStr');
        }
      }
      if (wordBlocks.isNotEmpty) {
        if (sectionCount > 0) buffer.writeln();
        buffer.writeln(wordBlocks.join('\n\n'));
        sectionCount++;
      }
    }

    // 4. Tafsir section
    if (hasTafsir) {
      final seenRanges = <AyahRange>{};
      final tafsirBlocks = <String>[];
      for (final item in items) {
        final tf = item.tafsir;
        if (tf != null && tf.paragraphs.isNotEmpty) {
          if (!seenRanges.add(tf.covers)) continue; // deduplicate covered passages!
          final String rangeLabel;
          if (tf.covers.first == tf.covers.last) {
            rangeLabel = tf.covers.first.key;
          } else if (tf.covers.first.surah == tf.covers.last.surah) {
            rangeLabel =
                '${tf.covers.first.key}–${tf.covers.last.ayah}';
          } else {
            rangeLabel = '${tf.covers.first.key}–${tf.covers.last.key}';
          }
          final title = tf.title.trim().isNotEmpty
              ? tf.title.trim()
              : 'Tafsir';
          final header = 'Tafsir — $title ($rangeLabel)';
          final body = tf.paragraphs
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .join('\n\n');
          tafsirBlocks.add('$header\n$body');
        }
      }
      if (tafsirBlocks.isNotEmpty) {
        if (sectionCount > 0) buffer.writeln();
        buffer.writeln(tafsirBlocks.join('\n\n'));
        sectionCount++;
      }
    }

    // Fallback if no content parts were enabled but reference is true
    if (sectionCount == 0 && recipe.reference) {
      final refs = items.map((i) => i.ayah.key).join(', ');
      buffer.writeln('($refs)');
    }

    var fullText = buffer.toString().trim();
    var isTruncated = false;
    if (fullText.length > maxCharacters) {
      isTruncated = true;
      var cutIndex = fullText.lastIndexOf('\n', maxCharacters);
      if (cutIndex <= 0) cutIndex = maxCharacters;
      fullText = '${fullText.substring(0, cutIndex)}\n\n[... truncated]';
    }

    return AyahCopyResult(text: fullText, isTruncated: isTruncated);
  }
}

