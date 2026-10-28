import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/mushaf/controller/page_side.dart';

class _FailingStore implements PageSideStore {
  @override
  PageSide load() => PageSide.info;

  @override
  Future<void> save(PageSide side) async => throw StateError('disk full');
}

void main() {
  test('opens on the info side by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(pageSideProvider), PageSide.info);
  });

  test('opens on the side that was kept', () {
    final container = ProviderContainer(
      overrides: [
        pageSideStoreProvider.overrideWithValue(
          MemoryPageSideStore(PageSide.quran),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(pageSideProvider), PageSide.quran);
  });

  test('a change is kept in the store', () async {
    final store = MemoryPageSideStore();
    final container = ProviderContainer(
      overrides: [pageSideStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container.read(pageSideProvider.notifier).set(PageSide.quran);
    expect(container.read(pageSideProvider), PageSide.quran);
    expect(store.load(), PageSide.quran);

    await container.read(pageSideProvider.notifier).set(PageSide.info);
    expect(store.load(), PageSide.info);
  });

  test('the choice holds for the session even if it cannot be saved', () async {
    final container = ProviderContainer(
      overrides: [pageSideStoreProvider.overrideWithValue(_FailingStore())],
    );
    addTearDown(container.dispose);

    await container.read(pageSideProvider.notifier).set(PageSide.quran);
    expect(container.read(pageSideProvider), PageSide.quran);
  });
}
