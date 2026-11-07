import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/ayah_copy.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';

void main() {
  group('CopyRecipe', () {
    test('encodes and decodes with default', () {
      expect(
        CopyRecipe.decode(null),
        equals(CopyRecipe.arabicAndTranslation),
      );
      expect(
        CopyRecipe.decode(''),
        equals(CopyRecipe.arabicAndTranslation),
      );
    });

    test('round-trips all presets and combinations', () {
      for (final recipe in [
        CopyRecipe.arabicOnly,
        CopyRecipe.arabicAndTranslation,
        CopyRecipe.everything,
        const CopyRecipe(parts: {CopyPart.tafsir}, reference: false),
        const CopyRecipe(parts: {CopyPart.words}, reference: true),
      ]) {
        final encoded = recipe.encode();
        final decoded = CopyRecipe.decode(encoded);
        expect(decoded, equals(recipe));
      }
    });
  });

  group('AyahCopy.build', () {
    final ayah255 = AyahWords(
      key: '2:255',
      arabic: 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ',
      words: const [
        WordGloss('ٱللَّهُ', 'Allah'),
        WordGloss('لَآ', 'no'),
        WordGloss('إِلَٰهَ', 'deity'),
        WordGloss('إِلَّا', 'except'),
        WordGloss('هُوَ', 'Him'),
      ],
    );

    final ayah256 = AyahWords(
      key: '2:256',
      arabic: 'لَآ إِكْرَاهَ فِى ٱلدِّينِ',
      words: const [
        WordGloss('لَآ', 'no'),
        WordGloss('إِكْرَاهَ', 'compulsion'),
        WordGloss('فِى', 'in'),
        WordGloss('ٱلدِّينِ', 'the religion'),
      ],
    );

    test('empty input returns empty string', () {
      final res = AyahCopy.build([], CopyRecipe.arabicAndTranslation);
      expect(res.text, isEmpty);
      expect(res.isTruncated, isFalse);
    });

    test('formats Arabic only with reference', () {
      final input = AyahCopyInput(ayah: ayah255);
      final res = AyahCopy.build([input], CopyRecipe.arabicOnly);
      expect(res.text, 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ (2:255)');
    });

    test('formats Arabic only without reference', () {
      final input = AyahCopyInput(ayah: ayah255);
      final res = AyahCopy.build(
        [input],
        const CopyRecipe(parts: {CopyPart.arabic}, reference: false),
      );
      expect(res.text, 'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ');
    });

    test('formats Arabic and Translation with footnotes stripped and author included', () {
      final input = AyahCopyInput(
        ayah: ayah255,
        translation: (
          text:
              'Allah — there is no deity except Him<sup foot_note="123">1</sup>, the Ever-Living.',
          author: 'Saheeh International',
        ),
      );
      final res = AyahCopy.build([input], CopyRecipe.arabicAndTranslation);
      expect(
        res.text,
        'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ (2:255)\n\n'
        'Translation — Saheeh International\n'
        'Allah — there is no deity except Him, the Ever-Living.',
      );
    });

    test('formats everything with word-by-word and tafsir', () {
      final input = AyahCopyInput(
        ayah: ayah255,
        translation: (
          text: 'Allah — there is no deity except Him.',
          author: 'Saheeh International',
        ),
        tafsir: (
          covers: AyahRange(const AyahRef(2, 255), const AyahRef(2, 255)),
          title: 'Ibn Kathir',
          paragraphs: ['This is Ayat al-Kursi.', 'It has a great status.'],
        ),
      );

      final res = AyahCopy.build([input], CopyRecipe.everything);
      expect(
        res.text,
        'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ (2:255)\n\n'
        'Translation — Saheeh International\n'
        'Allah — there is no deity except Him.\n\n'
        'Word by word\n'
        'ٱللَّهُ = Allah · لَآ = no · إِلَٰهَ = deity · إِلَّا = except · هُوَ = Him\n\n'
        'Tafsir — Ibn Kathir (2:255)\n'
        'This is Ayat al-Kursi.\n\n'
        'It has a great status.',
      );
    });

    test('deduplicates multi-ayah tafsir passages', () {
      final sharedRange = AyahRange(const AyahRef(2, 255), const AyahRef(2, 256));
      final items = [
        AyahCopyInput(
          ayah: ayah255,
          translation: (text: 'Verse 255 translation', author: 'Test'),
          tafsir: (
            covers: sharedRange,
            title: 'Ibn Kathir',
            paragraphs: ['Combined tafsir commentary.'],
          ),
        ),
        AyahCopyInput(
          ayah: ayah256,
          translation: (text: 'Verse 256 translation', author: 'Test'),
          tafsir: (
            covers: sharedRange,
            title: 'Ibn Kathir',
            paragraphs: ['Combined tafsir commentary.'],
          ),
        ),
      ];

      final res = AyahCopy.build(items, CopyRecipe.everything);
      // Tafsir section should appear once
      final tafsirMatches = 'Tafsir — Ibn Kathir (2:255–256)'.allMatches(res.text);
      expect(tafsirMatches.length, 1);
      expect(res.text.contains('(2:255) Verse 255 translation'), isTrue);
      expect(res.text.contains('(2:256) Verse 256 translation'), isTrue);
    });

    test('prepends AI instruction when provided', () {
      final input = AyahCopyInput(ayah: ayah255);
      final res = AyahCopy.build(
        [input],
        CopyRecipe.arabicOnly,
        aiInstruction: AiCopyInstructions.explain,
      );
      expect(
        res.text,
        '${AiCopyInstructions.explain}\n\n'
        'ٱللَّهُ لَآ إِلَٰهَ إِلَّا هُوَ (2:255)',
      );
    });

    test('truncates at maxCharacters if output is huge', () {
      final longParas = List.generate(5000, (i) => 'Paragraph $i of lengthy text comment.');
      final input = AyahCopyInput(
        ayah: ayah255,
        tafsir: (
          covers: AyahRange(const AyahRef(2, 255), const AyahRef(2, 255)),
          title: 'Lengthy Tafsir',
          paragraphs: longParas,
        ),
      );
      final res = AyahCopy.build(
        [input],
        const CopyRecipe(parts: {CopyPart.tafsir}),
      );
      expect(res.isTruncated, isTrue);
      expect(res.text.length <= AyahCopy.maxCharacters + 50, isTrue);
      expect(res.text.endsWith('[... truncated]'), isTrue);
    });
  });
}

