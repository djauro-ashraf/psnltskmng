import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/data/mushaf_source.dart';

/// Where the pages come from. The app overrides it with the downloaded Quran
/// (`app/dependencies.dart`); until then, and in tests, there is none.
final mushafSourceProvider = Provider<MushafSource>(
  (ref) => const NoMushafSource(),
);

/// One page of the chosen edition, loaded with its font. Kept while a screen
/// shows it and shortly after (the screens next to it are built before they
/// are reached).
final mushafPageProvider = FutureProvider.autoDispose
    .family<MushafPageResult, int>(
      (ref, page) => ref
          .watch(mushafSourceProvider)
          .load(ref.watch(mushafEditionProvider), page),
    );

/// The family of the Unicode font (banner, basmallah), null when not installed.
final mushafTextFontProvider = FutureProvider<String?>(
  (ref) => ref.watch(mushafSourceProvider).loadTextFont(),
);
