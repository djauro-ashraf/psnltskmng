import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';
import 'package:personaltskmng/quran_data/models/reading_banners.dart';
import 'package:personaltskmng/quran_data/models/words_model.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

import '../support/divisions_fixture.dart';

/// `banner:surah`, `ayah:2:255`, `edge:endOfQuran`: the shape of a row.
String _shape(StreamItem item) => switch (item) {
  BannerItem(:final banner) => 'banner:${banner.kind.name}',
  AyahItem(:final at) => 'ayah:${at.key}',
  EdgeItem(:final kind) => 'edge:${kind.name}',
};

List<String> _shapes(List<StreamItem> items) => [for (final i in items) _shape(i)];

List<String> _ayahKeys(List<StreamItem> items) => [
  for (final item in items)
    if (item is AyahItem) item.at.key,
];

({WordsModel model, List<int> readied}) _make(
  WordsUnit unit, {
  PageLocator? locator,
  AyahRange? stop,
}) {
  final readied = <int>[];
  final model = WordsModel(
    unit: unit,
    locator: locator ?? missingLayout(),
    ready: (surah) async {
      readied.add(surah);
    },
    stop: stop,
  );
  return (model: model, readied: readied);
}

void main() {
  final fixture = DivisionsFixture.instance;

  group('opening', () {
    test('at the first ayah there is nothing above but the start', () async {
      final (:model, :readied) = _make(WordsUnit.surah);
      expect(await model.start(const AyahRef(1, 1)), isTrue);
      expect(_shapes(model.backward), ['edge:startOfQuran']);
      expect(model.backwardDone, isTrue);
      expect(model.forwardDone, isFalse);
      expect(model.forward, isEmpty);
      expect(readied, isEmpty);
    });

    test('a surah banner comes before the first ayah of the surah', () async {
      final (:model, :readied) = _make(WordsUnit.surah);
      await model.start(const AyahRef(1, 1));
      await model.extendForward(3);
      expect(_shapes(model.forward), [
        'banner:surah',
        'ayah:1:1',
        'ayah:1:2',
        'ayah:1:3',
      ]);
      expect(readied, [1]);
    });

    test('opening in the middle, the rows start at that ayah', () async {
      final model = _make(WordsUnit.surah).model;
      // 2:10 to 2:20 hold no start of any division, so there are no banners.
      await model.start(const AyahRef(2, 12));
      await model.extendForward(2);
      await model.extendBackward(2);
      expect(_shapes(model.forward), ['ayah:2:12', 'ayah:2:13']);
      expect(_shapes(model.backward), ['ayah:2:11', 'ayah:2:10']);
      expect(model.backwardDone, isFalse);
    });

    test('the unit asked for cannot be worked out without the layout', () async {
      final model = _make(WordsUnit.page).model;
      expect(await model.start(const AyahRef(2, 255)), isFalse);
      expect(model.layoutMissing, isTrue);
      expect(model.forward, isEmpty);
      expect(model.backward, isEmpty);
    });
  });

  group('going forward', () {
    test('the next unit is just more rows, with its own banner', () async {
      final (:model, :readied) = _make(WordsUnit.surah);
      await model.start(const AyahRef(1, 6));
      await model.extendForward(3);
      expect(_shapes(model.forward), [
        'ayah:1:6',
        'ayah:1:7',
        'banner:surah',
        'ayah:2:1',
      ]);
      // One `ready` per surah, not one per ayah.
      expect(readied, [1, 2]);
    });

    test('a step makes about the number of ayahs asked for', () async {
      final model = _make(WordsUnit.surah).model;
      await model.start(const AyahRef(2, 10));
      await model.extendForward(7);
      expect(_ayahKeys(model.forward), [
        for (var a = 10; a <= 16; a++) '2:$a',
      ]);
      await model.extendForward(3);
      expect(_ayahKeys(model.forward), [
        for (var a = 10; a <= 19; a++) '2:$a',
      ]);
    });

    test('the end of the Quran ends the stream with a card', () async {
      final model = _make(WordsUnit.surah).model;
      await model.start(const AyahRef(114, 4));
      await model.extendForward(10);
      expect(_shapes(model.forward), [
        'ayah:114:4',
        'ayah:114:5',
        'ayah:114:6',
        'edge:endOfQuran',
      ]);
      expect(model.forwardDone, isTrue);
      // Asking again adds nothing.
      await model.extendForward(10);
      expect(model.forward, hasLength(4));
    });

    test('two asks at once are one step', () async {
      final model = _make(WordsUnit.surah).model;
      await model.start(const AyahRef(2, 1));
      final first = model.extendForward(5);
      final second = model.extendForward(5);
      expect(identical(first, second), isTrue);
      await first;
      expect(model.forward.whereType<AyahItem>(), hasLength(5));
    });

    test('a step that fails can be asked again', () async {
      var fail = true;
      final model = WordsModel(
        unit: WordsUnit.surah,
        locator: missingLayout(),
        ready: (surah) async {
          if (fail) throw StateError('not read');
        },
      );
      await model.start(const AyahRef(2, 1));
      await expectLater(model.extendForward(3), throwsStateError);
      expect(model.forward, isEmpty);
      fail = false;
      await model.extendForward(3);
      expect(model.forward.whereType<AyahItem>(), hasLength(3));
    });
  });

  group('going back', () {
    test('the rows above the opening ayah come nearest first', () async {
      final model = _make(WordsUnit.surah).model;
      await model.start(const AyahRef(2, 3));
      await model.extendBackward(2);
      // The card, then the banner that sits above it.
      expect(_shapes(model.backward), ['ayah:2:2', 'ayah:2:1', 'banner:surah']);
      expect(model.backwardDone, isFalse);
    });

    test('going on back reaches the start of the Quran', () async {
      final (:model, :readied) = _make(WordsUnit.surah);
      await model.start(const AyahRef(2, 1));
      await model.extendBackward(20);
      final shapes = _shapes(model.backward);
      expect(shapes.first, 'ayah:1:7');
      expect(shapes.sublist(shapes.length - 3), [
        'ayah:1:1',
        'banner:surah',
        'edge:startOfQuran',
      ]);
      expect(model.backwardDone, isTrue);
      expect(readied.toSet(), {1});
    });
  });

  group('banners follow the unit', () {
    Future<ReadingBanner> bannerAt(WordsUnit unit, AyahRef at) async {
      final model = _make(unit).model;
      await model.start(at);
      await model.extendForward(1);
      return (model.forward.first as BannerItem).banner;
    }

    test('a ruku start is a slim line, and a full banner for the ruku unit', () async {
      final slim = await bannerAt(WordsUnit.surah, const AyahRef(2, 8));
      expect(slim.kind, BannerKind.ruku);
      expect(slim.full, isFalse);

      final full = await bannerAt(WordsUnit.ruku, const AyahRef(2, 8));
      expect(full.kind, BannerKind.ruku);
      expect(full.full, isTrue);
      expect(full.ruku?.number, 2);
    });

    test('a hizb start is a band, and a full banner for the hizb unit', () async {
      final band = await bannerAt(WordsUnit.surah, const AyahRef(2, 75));
      expect(band.kind, BannerKind.hizb);
      expect(band.full, isFalse);

      final full = await bannerAt(WordsUnit.hizb, const AyahRef(2, 75));
      expect(full.kind, BannerKind.hizb);
      expect(full.full, isTrue);
      expect(full.hizb, 2);
    });

    test('a juz start is a juz banner whatever the unit', () async {
      for (final unit in [WordsUnit.surah, WordsUnit.juz, WordsUnit.quran]) {
        final banner = await bannerAt(unit, const AyahRef(2, 142));
        expect(banner.kind, BannerKind.juz, reason: '$unit');
        expect(banner.juz, 2, reason: '$unit');
      }
    });
  });

  group('the page unit', () {
    test('the ayah that runs over a page says so, and is not shown twice', () async {
      final locator = fixture.locatorWithContinuations({51});
      final first50 = DivisionsFixture.refOf(fixture.pages[49]['start']);
      final model = _make(WordsUnit.page, locator: locator).model;
      expect(await model.start(first50), isTrue);
      // Page 50 holds 3:1 to 3:9; 3:9 goes on over page 51.
      await model.extendForward(9);
      final cards = model.forward.whereType<AyahItem>().toList();
      expect(cards, hasLength(9));
      for (final card in cards) {
        expect(
          card.continuesOnPage,
          card.at == const AyahRef(3, 9) ? 51 : isNull,
          reason: '${card.at}',
        );
      }
      // The first ayah of the Surah and of the page: one banner, with the page.
      final banner = (model.forward.first as BannerItem).banner;
      expect(banner.kind, BannerKind.surah);
      expect(banner.page, 50);

      // Going on into page 51 never repeats 3:9.
      await model.extendForward(5);
      final keys = _ayahKeys(model.forward);
      expect(keys.toSet(), hasLength(keys.length));
      expect(keys[9], '3:10');
    });
  });

  group('a part or a range stops the stream', () {
    final stop = AyahRange(const AyahRef(2, 10), const AyahRef(2, 12));

    test('"Keep reading" tiles at both ends', () async {
      final model = _make(WordsUnit.surah, stop: stop).model;
      expect(await model.start(const AyahRef(2, 10)), isTrue);
      expect(_shapes(model.backward), ['edge:keepReadingBack']);
      expect(model.backwardDone, isTrue);

      await model.extendForward(10);
      expect(_shapes(model.forward), [
        'ayah:2:10',
        'ayah:2:11',
        'ayah:2:12',
        'edge:keepReadingForward',
      ]);
      expect(model.forwardDone, isTrue);
    });

    test('inside the run the stream is free on the side it is far from', () async {
      final model = _make(WordsUnit.surah, stop: stop).model;
      await model.start(const AyahRef(2, 11));
      // 2:10 is inside the run: no tile above yet.
      expect(model.backward, isEmpty);
      await model.extendBackward(5);
      expect(_shapes(model.backward), ['ayah:2:10', 'edge:keepReadingBack']);
    });

    test('"Keep reading" below goes on from where it stopped', () async {
      final model = _make(WordsUnit.surah, stop: stop).model;
      await model.start(const AyahRef(2, 10));
      await model.extendForward(10);
      model.releaseForward();
      expect(
        model.forward.any(
          (i) => i is EdgeItem && i.kind == EdgeKind.keepReadingForward,
        ),
        isFalse,
      );
      expect(model.forwardDone, isFalse);
      // Above, the tile is still there until it is tapped.
      expect(model.stop, isNotNull);

      await model.extendForward(2);
      expect(_ayahKeys(model.forward), [
        '2:10',
        '2:11',
        '2:12',
        '2:13',
        '2:14',
      ]);
    });

    test('"Keep reading" above goes on upward', () async {
      final model = _make(WordsUnit.surah, stop: stop).model;
      await model.start(const AyahRef(2, 10));
      model.releaseBackward();
      expect(model.backward, isEmpty);
      expect(model.backwardDone, isFalse);
      await model.extendBackward(2);
      expect(_ayahKeys(model.backward), ['2:9', '2:8']);
    });

    test('with both tiles tapped the stop is gone', () async {
      final model = _make(WordsUnit.surah, stop: stop).model;
      await model.start(const AyahRef(2, 10));
      await model.extendForward(10);
      model.releaseForward();
      model.releaseBackward();
      expect(model.stop, isNull);
    });

    test('a release with nothing to release changes nothing', () async {
      final model = _make(WordsUnit.surah).model;
      await model.start(const AyahRef(2, 10));
      model.releaseForward();
      model.releaseBackward();
      expect(model.stop, isNull);
      expect(model.forwardDone, isFalse);
    });

    test('opening outside the run drops the stop', () async {
      final model = _make(WordsUnit.surah, stop: stop).model;
      await model.start(const AyahRef(3, 1));
      expect(model.stop, isNull);
      expect(model.backward, isEmpty);
      await model.extendForward(2);
      expect(_ayahKeys(model.forward), ['3:1', '3:2']);
    });
  });
}
