import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';
import 'package:personaltskmng/quran_data/models/ayah_copy.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';

abstract final class AyahCopyLoader {
  static Future<List<AyahCopyInput>> load({
    required WidgetRef ref,
    required AyahRange range,
    required CopyRecipe recipe,
    String? tafsirSourceId,
  }) async {
    final ayahs = [
      for (var i = range.first.index; i <= range.last.index; i++)
        QuranDivisions.fromIndex(i),
    ];
    if (ayahs.isEmpty) return const [];

    // Group ayahs by surah
    final bySurah = <int, List<AyahRef>>{};
    for (final a in ayahs) {
      bySurah.putIfAbsent(a.surah, () => []).add(a);
    }

    // 1. Fetch SurahWords for each surah
    final wordsCache = <int, List<AyahWords>?>{};
    for (final s in bySurah.keys) {
      wordsCache[s] = await ref.read(surahWordsProvider(s).future);
    }

    // 2. Fetch Translation if needed
    final translationCache = <int, Map<String, TranslationText>?>{};
    String? translationAuthor;
    if (recipe.parts.contains(CopyPart.translation)) {
      final transId = await ref.read(selectedTranslationIdProvider.future);
      if (transId != null) {
        final installed =
            await ref.read(installedTranslationsProvider.future);
        final pack = installed.where((p) => p.id == transId).firstOrNull;
        translationAuthor = pack?.author ?? pack?.title;
        for (final s in bySurah.keys) {
          translationCache[s] = await ref.read(
            surahTranslationProvider((surah: s, id: transId)).future,
          );
        }
      }
    }

    // 3. Fetch Tafsir if needed
    final tafsirCache =
        <String, ({AyahRange covers, String title, List<String> paragraphs})>{};
    if (recipe.parts.contains(CopyPart.tafsir)) {
      final content = ref.read(tafsirContentProvider);
      final sources = await content.installed();
      final source =
          sources.where((s) => s.id == tafsirSourceId).firstOrNull ??
          sources.firstOrNull;
      if (source != null) {
        for (final a in ayahs) {
          final found = await content.lookup(source.id, a);
          if (found != null && found.passage.paragraphs.isNotEmpty) {
            tafsirCache[a.key] = (
              covers: found.passage.covers,
              title: source.title,
              paragraphs: found.passage.paragraphs,
            );
          }
        }
      }
    }

    // 4. Assemble AyahCopyInput list
    final results = <AyahCopyInput>[];
    for (final a in ayahs) {
      final sWords = wordsCache[a.surah];
      final AyahWords ayahWords;
      if (sWords != null && a.ayah <= sWords.length && a.ayah > 0) {
        ayahWords = sWords[a.ayah - 1];
      } else {
        ayahWords = AyahWords(key: a.key, arabic: '', words: const []);
      }

      final trMap = translationCache[a.surah];
      final trText = trMap?[a.key];
      final ({String text, String? author})? trInput = trText != null
          ? (text: trText.text, author: translationAuthor)
          : null;

      final tfInput = tafsirCache[a.key];

      results.add(
        AyahCopyInput(
          ayah: ayahWords,
          translation: trInput,
          tafsir: tfInput,
        ),
      );
    }

    return results;
  }
}

