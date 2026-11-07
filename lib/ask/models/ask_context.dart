import 'package:personaltskmng/domain/reference/quran_divisions.dart';

/// Pinned context attached to an Ask AI chat (e.g. an ayah, its translation,
/// word glosses, and tafsir passage).
final class AskContext {
  const AskContext({
    required this.ayah,
    required this.arabic,
    this.translation,
    this.translationAuthor,
    this.words,
    this.tafsirTitle,
    this.tafsirCovers,
    this.tafsirText,
    this.isTafsirTruncated = false,
    this.focusText,
  });

  /// Maximum characters of tafsir to include in context to prevent token overflows.
  static const int maxTafsirCharacters = 8000;

  final AyahRef ayah;
  final String arabic;
  final String? translation;
  final String? translationAuthor;
  final List<String>? words;
  final String? tafsirTitle;
  final AyahRange? tafsirCovers;
  final String? tafsirText;
  final bool isTafsirTruncated;

  /// Specific text user had selected in the UI when asking about this ayah.
  final String? focusText;

  Map<String, dynamic> toJson() => {
        'ayah': ayah.key,
        'arabic': arabic,
        if (translation != null) 'translation': translation,
        if (translationAuthor != null)
          'translationAuthor': translationAuthor,
        if (words != null) 'words': words,
        if (tafsirTitle != null) 'tafsirTitle': tafsirTitle,
        if (tafsirCovers != null)
          'tafsirCovers': {
            'first': tafsirCovers!.first.key,
            'last': tafsirCovers!.last.key,
          },
        if (tafsirText != null) 'tafsirText': tafsirText,
        if (isTafsirTruncated) 'isTafsirTruncated': isTafsirTruncated,
        if (focusText != null) 'focusText': focusText,
      };

  factory AskContext.fromJson(Map<String, dynamic> json) {
    final rawAyah = json['ayah'] as String? ?? '1:1';
    final parsedAyah = AyahRef.tryParse(rawAyah) ?? const AyahRef(1, 1);

    AyahRange? covers;
    final rawCovers = json['tafsirCovers'];
    if (rawCovers is Map<String, dynamic>) {
      final f = AyahRef.tryParse(rawCovers['first'] as String? ?? '');
      final l = AyahRef.tryParse(rawCovers['last'] as String? ?? '');
      if (f != null && l != null) {
        covers = AyahRange(f, l);
      }
    }

    final rawWords = json['words'];
    List<String>? words;
    if (rawWords is List) {
      words = [for (final w in rawWords) if (w is String) w];
    }

    return AskContext(
      ayah: parsedAyah,
      arabic: json['arabic'] as String? ?? '',
      translation: json['translation'] as String?,
      translationAuthor: json['translationAuthor'] as String?,
      words: words,
      tafsirTitle: json['tafsirTitle'] as String?,
      tafsirCovers: covers,
      tafsirText: json['tafsirText'] as String?,
      isTafsirTruncated: json['isTafsirTruncated'] as bool? ?? false,
      focusText: json['focusText'] as String?,
    );
  }
}

