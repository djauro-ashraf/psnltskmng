import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which side of a page screen is showing: its info and notes, or the Quran
/// page itself.
enum PageSide { info, quran }

/// Where the choice is kept. A view preference, so it is not part of the
/// settings and not in a backup.
abstract interface class PageSideStore {
  PageSide load();

  Future<void> save(PageSide side);
}

/// Keeps the choice for the session only (the default, and what tests use).
class MemoryPageSideStore implements PageSideStore {
  MemoryPageSideStore([this._side = PageSide.info]);

  PageSide _side;

  @override
  PageSide load() => _side;

  @override
  Future<void> save(PageSide side) async => _side = side;
}

final pageSideStoreProvider = Provider<PageSideStore>(
  (ref) => MemoryPageSideStore(),
);

/// The side the page screens open on, and the one-tap switch between them.
class PageSideNotifier extends Notifier<PageSide> {
  @override
  PageSide build() => ref.watch(pageSideStoreProvider).load();

  Future<void> set(PageSide side) async {
    if (side == state) return;
    state = side;
    try {
      await ref.read(pageSideStoreProvider).save(side);
    } catch (_) {
      // Only a view preference: the choice still holds for this session.
    }
  }
}

final pageSideProvider = NotifierProvider<PageSideNotifier, PageSide>(
  PageSideNotifier.new,
);
