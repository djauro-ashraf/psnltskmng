import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_providers.dart';
import 'package:personaltskmng/mushaf/models/page_ticks.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/data/pack_installer.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/data/quran_content.dart';
import 'package:personaltskmng/quran_data/models/juz_pages.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import 'package:personaltskmng/quran_data/models/page_divisions.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';
import 'package:personaltskmng/quran_data/models/quran_fonts.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';

/// The Quran folder on the device. Tests give a folder of their own.
final quranStorageProvider = FutureProvider<DirectoryPackStorage>((ref) async {
  final base = await getApplicationSupportDirectory();
  final root = Directory('${base.path}/quran');
  await root.create(recursive: true);
  return DirectoryPackStorage(root);
});

/// How bytes are fetched from a URL. Tests give a fake.
final quranFetchProvider = Provider<Fetch>((ref) {
  final fetcher = HttpFetcher();
  ref.onDispose(fetcher.close);
  return fetcher.call;
});

/// The downloaded Quran, read a page at a time.
final quranContentProvider = FutureProvider<QuranContent>(
  (ref) async => QuranRepository(await ref.watch(quranStorageProvider.future)),
);

/// The pack list of the developer's address; null while no address is set.
final quranManifestProvider = FutureProvider<QuranManifest?>((ref) async {
  final address = ref.watch(manifestUrlProvider);
  if (address.isEmpty) return null;
  final uri = Uri.tryParse(address);
  if (uri == null || !uri.hasScheme) {
    throw FormatException('"$address" is not a web address');
  }
  final bytes = await ref.watch(quranFetchProvider)(uri);
  return QuranManifest.parse(utf8.decode(bytes), uri);
});

/// The font packs, which do not come from the pack list: the page fonts of the
/// chosen edition, and the Unicode font.
final quranFontPacksProvider = Provider<List<QuranPack>>(
  (ref) => [
    QuranFonts.pageFonts(ref.watch(mushafEditionProvider)),
    QuranFonts.textFont(),
  ],
);

/// How much of a pack is on the device.
final packStatusProvider = FutureProvider.autoDispose
    .family<PackStatus, QuranPack>((ref, pack) async {
      ref.watch(quranDataControllerProvider.select((s) => s.revision));
      final storage = await ref.watch(quranStorageProvider.future);
      return storage.status(pack);
    });

/// The translations that are downloaded (known offline from their markers).
final installedTranslationsProvider =
    FutureProvider.autoDispose<List<InstalledPack>>((ref) async {
      ref.watch(quranDataControllerProvider.select((s) => s.revision));
      final storage = await ref.watch(quranStorageProvider.future);
      return [
        for (final pack in await storage.installed())
          if (pack.kind == QuranPackKind.translation) pack,
      ];
    });

/// The translation the Words view shows: the chosen one when it is
/// downloaded, else the first that is, else none.
final selectedTranslationIdProvider = FutureProvider.autoDispose<String?>((
  ref,
) async {
  final choice = ref.watch(translationChoiceProvider);
  // "Off" is a choice of its own: no translation, even when some is downloaded.
  if (choice == quranTranslationOff) return null;
  final installed = await ref.watch(installedTranslationsProvider.future);
  if (choice != null && installed.any((p) => p.id == choice)) return choice;
  return installed.isEmpty ? null : installed.first.id;
});

/// The ayahs a page of the chosen edition holds, in order; null when the lines
/// of that edition are not downloaded.
final pageVersesProvider = FutureProvider.autoDispose
    .family<List<String>?, int>((ref, page) async {
      final edition = ref.watch(mushafEditionProvider);
      final content = await ref.watch(quranContentProvider.future);
      return (await content.layoutPage(edition, page))?.verses;
    });

/// The ayahs of a page with their words; null when the words or the lines of the
/// page are not downloaded.
final wordsPageProvider = FutureProvider.autoDispose.family<PageWords?, int>((
  ref,
  page,
) async {
  final verses = await ref.watch(pageVersesProvider(page).future);
  if (verses == null) return null;
  final content = await ref.watch(quranContentProvider.future);
  final ayahs = await content.ayahs(verses);
  return ayahs == null ? null : PageWords(page: page, ayahs: ayahs);
});

/// The chosen translation of the ayahs of a page, by ayah key; null when none
/// is downloaded.
final translationPageProvider = FutureProvider.autoDispose
    .family<Map<String, TranslationText>?, int>((ref, page) async {
      final id = await ref.watch(selectedTranslationIdProvider.future);
      final verses = await ref.watch(pageVersesProvider(page).future);
      if (id == null || verses == null) return null;
      final content = await ref.watch(quranContentProvider.future);
      return content.translations(id, verses);
    });

/// Where an ayah is in the book of the chosen print, and which ayahs a page
/// holds (see `PageLocator`). Made again when the print or what is downloaded
/// changes, so it never answers for the wrong print.
final pageLocatorProvider = Provider<PageLocator>((ref) {
  final edition = ref.watch(mushafEditionProvider);
  // Taken now, not read later: a closure must not use `ref` after this
  // provider was rebuilt.
  final content = ref.watch(quranContentProvider.future);
  return PageLocator(
    (page) async => (await (await content).layoutPage(edition, page))?.verses,
  );
});

/// The pages of the 30 juz in the chosen print (the Browse list of juz, the
/// "Group by Juz" of the page list, the limit of a juz in the reader). Null when
/// the page lines of the print are not downloaded. Worked out from the layout
/// pack, never from the divisions file, and made again when the print or what
/// is downloaded changes (the locator it watches is).
final juzPagesProvider = FutureProvider<List<JuzPages>?>(
  (ref) => JuzPageTable.build(ref.watch(pageLocatorProvider)),
);

/// How long the words of a surah stay in memory after the last card that shows
/// them went away. Long enough to scroll back over what was just read, short
/// enough that five minutes of scrolling through the Quran never holds it all.
const Duration quranSurahKeepAlive = Duration(seconds: 90);

/// Keeps an auto-dispose provider for [duration] after it lost its last
/// listener (the pattern of the Riverpod docs). A provider that is only read
/// never had a listener, so whoever reads one ahead of its cards listens for a
/// moment and closes (see `WordsStreamView`): then the timer runs.
void _keepAliveFor(Ref ref, Duration duration) {
  final link = ref.keepAlive();
  Timer? timer;
  ref.onCancel(() => timer = Timer(duration, link.close));
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
}

/// All the ayahs of one surah with their words, index 0 being ayah 1; null when
/// the words are not downloaded. The Words stream reads them by surah: one
/// decoded line, shared by every card of the surah.
final surahWordsProvider = FutureProvider.autoDispose
    .family<List<AyahWords>?, int>((ref, surah) async {
      _keepAliveFor(ref, quranSurahKeepAlive);
      final content = await ref.watch(quranContentProvider.future);
      return content.ayahs([
        for (var a = 1; a <= QuranDivisions.ayahCountOf(surah); a++)
          '$surah:$a',
      ]);
    });

/// Which translation of which surah. A record, so two asks for the same pair
/// are the same provider.
typedef SurahTranslationKey = ({int surah, String id});

/// One whole surah of translation [SurahTranslationKey.id], by ayah key; null
/// when that translation is not downloaded. The Words stream keeps the id it
/// opened with, so a card never shows another translation than the rest of the
/// stream while the reader changes the choice (the stream is made again for the
/// new one, see `WordsStreamView`).
final surahTranslationProvider = FutureProvider.autoDispose
    .family<Map<String, TranslationText>?, SurahTranslationKey>((
      ref,
      key,
    ) async {
      _keepAliveFor(ref, quranSurahKeepAlive);
      final content = await ref.watch(quranContentProvider.future);
      return content.translations(key.id, [
        for (var a = 1; a <= QuranDivisions.ayahCountOf(key.surah); a++)
          '${key.surah}:$a',
      ]);
    });

/// The ticks of a Mushaf page of the chosen print (where a juz, a hizb or a ruku
/// begins). Empty when the lines of the page are not downloaded or hold no ayah
/// list.
final pageTicksProvider = FutureProvider.autoDispose
    .family<List<PageTick>, int>((ref, page) async {
      final edition = ref.watch(mushafEditionProvider);
      final content = await ref.watch(quranContentProvider.future);
      final layout = await content.layoutPage(edition, page);
      if (layout == null || layout.verses.isEmpty) return const [];
      var continued = false;
      if (page > 1) {
        final before = await content.layoutPage(edition, page - 1);
        continued =
            before != null &&
            before.verses.isNotEmpty &&
            before.verses.last == layout.verses.first;
      }
      return PageTicks.of(layout, continued: continued);
    });

/// The juz, the hizb and the rukus that begin on a page of the chosen print (the
/// page info card). Null while the layout of the print is not downloaded.
final pageDivisionsProvider = FutureProvider.autoDispose
    .family<PageDivisions?, int>(
      (ref, page) => PageDivisions.of(page, ref.watch(pageLocatorProvider)),
    );

/// What is being downloaded, and what went wrong.
final class QuranDataState {
  const QuranDataState({
    this.progress = const {},
    this.errors = const {},
    this.revision = 0,
  });

  /// Pack id to the part done (0 to 1), for the packs being downloaded.
  final Map<String, double> progress;

  /// Pack id to the last error.
  final Map<String, String> errors;

  /// Goes up each time something was downloaded or deleted.
  final int revision;

  QuranDataState copyWith({
    Map<String, double>? progress,
    Map<String, String>? errors,
    int? revision,
  }) => QuranDataState(
    progress: progress ?? this.progress,
    errors: errors ?? this.errors,
    revision: revision ?? this.revision,
  );
}

/// Downloads and deletes packs. A download goes on while the reader leaves the
/// screen (the controller lives with the app).
class QuranDataController extends Notifier<QuranDataState> {
  final Map<String, CancelToken> _tokens = {};

  @override
  QuranDataState build() => const QuranDataState();

  Future<void> install(QuranPack pack) async {
    if (_tokens.containsKey(pack.id)) return;
    final token = _tokens[pack.id] = CancelToken();
    _set(pack.id, progress: 0, error: null);
    try {
      final storage = await ref.read(quranStorageProvider.future);
      await PackInstaller(
        storage: storage,
        fetch: ref.read(quranFetchProvider),
      ).install(
        pack,
        cancel: token,
        onProgress: (fraction) => _set(pack.id, progress: fraction),
      );
      _set(pack.id, progress: null);
    } on DownloadCancelled {
      _set(pack.id, progress: null);
    } catch (error) {
      _set(pack.id, progress: null, error: '$error');
    } finally {
      _tokens.remove(pack.id);
      _changed();
    }
  }

  void cancel(String packId) => _tokens[packId]?.cancel();

  Future<void> delete(QuranPack pack) async {
    final storage = await ref.read(quranStorageProvider.future);
    await storage.delete(pack);
    _set(pack.id, progress: null, error: null);
    _changed();
  }

  void _set(String id, {double? progress, String? error}) {
    final newProgress = {...state.progress};
    final newErrors = {...state.errors};
    if (progress == null) {
      newProgress.remove(id);
    } else {
      newProgress[id] = progress;
    }
    if (error == null) {
      newErrors.remove(id);
    } else {
      newErrors[id] = error;
    }
    state = state.copyWith(progress: newProgress, errors: newErrors);
  }

  /// What is on the device changed: whatever read it must read it again.
  void _changed() {
    state = state.copyWith(revision: state.revision + 1);
    ref
      ..invalidate(quranContentProvider)
      ..invalidate(mushafSourceProvider)
      ..invalidate(mushafPageProvider)
      ..invalidate(mushafTextFontProvider)
      ..invalidate(pageVersesProvider)
      ..invalidate(wordsPageProvider)
      ..invalidate(translationPageProvider)
      ..invalidate(surahWordsProvider)
      ..invalidate(surahTranslationProvider)
      ..invalidate(pageTicksProvider);
  }
}

final quranDataControllerProvider =
    NotifierProvider<QuranDataController, QuranDataState>(
      QuranDataController.new,
    );
