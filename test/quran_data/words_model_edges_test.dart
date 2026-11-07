import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';
import 'package:personaltskmng/quran_data/models/unit_edges.dart';
import 'package:personaltskmng/quran_data/models/words_model.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

import '../support/divisions_fixture.dart';

String _shape(StreamItem item) => switch (item) {
      BannerItem(:final banner) => 'banner:${banner.kind.name}',
      AyahItem(:final at) => 'ayah:${at.key}',
      EdgeItem(:final kind) => 'edge:${kind.name}',
    };

List<String> _shapes(List<StreamItem> items) =>
    [for (final i in items) _shape(i)];

WordsModel _makeModel({
  required WordsUnit unit,
  UnitEdge edgeMode = UnitEdge.flow,
  PageLocator? locator,
  AyahRange? stop,
}) {
  return WordsModel(
    unit: unit,
    locator: locator ?? missingLayout(),
    ready: (surah) async {},
    stop: stop,
    edgeMode: edgeMode,
  );
}

void main() {
  DivisionsFixture.instance;

  group('UnitEdge.flow', () {
    test('extends seamlessly past surah boundary without edge tile', () async {
      final model = _makeModel(
        unit: WordsUnit.surah,
        edgeMode: UnitEdge.flow,
      );
      // Start near end of Surah 1 (7 ayahs)
      await model.start(const AyahRef(1, 5));
      await model.extendForward(10);

      // Should contain 1:5, 1:6, 1:7, banner:surah, 2:1, 2:2...
      final shapes = _shapes(model.forward);
      expect(shapes, contains('ayah:1:7'));
      expect(shapes, contains('banner:surah'));
      expect(shapes, contains('ayah:2:1'));
      expect(shapes, isNot(contains('edge:unitEndForward')));
      expect(model.forwardDone, isFalse);
    });
  });

  group('UnitEdge.gate', () {
    test('stops at end of unit with unitEndForward edge item', () async {
      final model = _makeModel(
        unit: WordsUnit.surah,
        edgeMode: UnitEdge.gate,
      );
      await model.start(const AyahRef(1, 5));
      await model.extendForward(10);

      final shapes = _shapes(model.forward);
      expect(shapes, contains('ayah:1:7'));
      expect(shapes.last, 'edge:unitEndForward');
      expect(model.forwardDone, isTrue);

      final edge = model.forward.last as EdgeItem;
      expect(edge.kind, EdgeKind.unitEndForward);
      expect(edge.edgeMode, UnitEdge.gate);
      expect(edge.unitLabel, isNotNull);
    });

    test('passForward removes gate and extends into next unit', () async {
      final model = _makeModel(
        unit: WordsUnit.surah,
        edgeMode: UnitEdge.gate,
      );
      await model.start(const AyahRef(1, 5));
      await model.extendForward(10);

      expect(model.forwardDone, isTrue);
      expect(_shapes(model.forward).last, 'edge:unitEndForward');

      // Now pass the gate
      await model.passForward();
      expect(model.forwardDone, isFalse);
      expect(_shapes(model.forward).contains('edge:unitEndForward'), isFalse);

      // Extend again into Surah 2
      await model.extendForward(5);
      final shapes = _shapes(model.forward);
      expect(shapes, contains('banner:surah'));
      expect(shapes, contains('ayah:2:1'));
    });

    test('backward gate stops before start of unit and passBackward passes it',
        () async {
      final model = _makeModel(
        unit: WordsUnit.surah,
        edgeMode: UnitEdge.gate,
      );
      // Start at 2:2
      await model.start(const AyahRef(2, 2));
      // Backward will reach 2:1, and then attempt 1:7 (outside fence of surah 2)
      await model.extendBackward(5);

      final shapes = _shapes(model.backward);
      expect(shapes, contains('ayah:2:1'));
      expect(shapes.last, 'edge:unitStartBack');
      expect(model.backwardDone, isTrue);

      final edge = model.backward.last as EdgeItem;
      expect(edge.kind, EdgeKind.unitStartBack);
      expect(edge.edgeMode, UnitEdge.gate);

      // Pass backward
      await model.passBackward();
      expect(model.backwardDone, isFalse);
      expect(_shapes(model.backward).contains('edge:unitStartBack'), isFalse);

      await model.extendBackward(5);
      expect(_shapes(model.backward), contains('ayah:1:7'));
    });
  });

  group('UnitEdge.locked', () {
    test('stops at end of unit with locked edge tile', () async {
      final model = _makeModel(
        unit: WordsUnit.surah,
        edgeMode: UnitEdge.locked,
      );
      await model.start(const AyahRef(1, 6));
      await model.extendForward(5);

      final shapes = _shapes(model.forward);
      expect(shapes, contains('ayah:1:7'));
      expect(shapes.last, 'edge:unitEndForward');
      expect(model.forwardDone, isTrue);

      final edge = model.forward.last as EdgeItem;
      expect(edge.kind, EdgeKind.unitEndForward);
      expect(edge.edgeMode, UnitEdge.locked);
    });
  });
}

