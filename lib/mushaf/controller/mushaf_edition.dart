import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';

/// Where the chosen edition is kept (a view preference, not in the settings and
/// not in a backup). In memory by default and in tests.
abstract interface class MushafEditionStore {
  MushafEdition load();

  Future<void> save(MushafEdition edition);
}

class MemoryMushafEditionStore implements MushafEditionStore {
  MemoryMushafEditionStore([this._edition = MushafEdition.standard]);

  MushafEdition _edition;

  @override
  MushafEdition load() => _edition;

  @override
  Future<void> save(MushafEdition edition) async => _edition = edition;
}

final mushafEditionStoreProvider = Provider<MushafEditionStore>(
  (ref) => MemoryMushafEditionStore(),
);

/// The print of the mushaf the reader follows: the Quran side, its fonts and
/// the ayahs the Words view lists for a page all use it.
class MushafEditionNotifier extends Notifier<MushafEdition> {
  @override
  MushafEdition build() => ref.watch(mushafEditionStoreProvider).load();

  Future<void> set(MushafEdition edition) async {
    if (edition == state) return;
    state = edition;
    try {
      await ref.read(mushafEditionStoreProvider).save(edition);
    } catch (_) {
      // Only a view preference: the choice still holds for this session.
    }
  }
}

final mushafEditionProvider =
    NotifierProvider<MushafEditionNotifier, MushafEdition>(
      MushafEditionNotifier.new,
    );
