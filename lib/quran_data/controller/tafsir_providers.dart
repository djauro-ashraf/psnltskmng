import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';

/// Where the tafsirs are read from. Nothing is downloaded yet; the data side
/// overrides this in `app/dependencies.dart` when it exists (see
/// `TafsirContent`).
final tafsirContentProvider = Provider<TafsirContent>(
  (ref) => const NoTafsirContent(),
);

/// The tafsirs that are downloaded. The Tafsir button of an ayah card and of the
/// Mushaf selection bar shows only when this is not empty.
final tafsirSourcesProvider = FutureProvider.autoDispose<List<TafsirSource>>((
  ref,
) {
  ref.watch(quranDataControllerProvider.select((state) => state.revision));
  return ref.watch(tafsirContentProvider).installed();
});

/// The ayahs the first downloaded tafsir comments on together with [ayah]
/// (`2:6–7`), for the button label; null when it has no passage for it.
final tafsirCoverProvider = FutureProvider.autoDispose
    .family<AyahRange?, AyahRef>((ref, ayah) async {
      final sources = await ref.watch(tafsirSourcesProvider.future);
      if (sources.isEmpty) return null;
      return ref.watch(tafsirContentProvider).coverOf(sources.first.id, ayah);
    });
