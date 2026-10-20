import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';

void main() {
  group('model lists', () {
    test('every provider offers models, with unique plain ids', () {
      for (final provider in aiProviderInfos) {
        expect(provider.models, isNotEmpty, reason: provider.id);
        final ids = [for (final m in provider.models) m.id];
        expect(ids.toSet().length, ids.length, reason: '${provider.id} ids');
        for (final id in ids) {
          expect(id.trim(), id, reason: id);
          expect(id, isNotEmpty);
          expect(id, isNot(contains(' ')), reason: id);
        }
      }
    });

    test('exactly one model per provider is recommended', () {
      for (final provider in aiProviderInfos) {
        final recommended = [
          for (final m in provider.models)
            if (m.recommended) m.id,
        ];
        expect(recommended, hasLength(1), reason: provider.id);
      }
    });

    test('the recommended model is listed first', () {
      for (final provider in aiProviderInfos) {
        expect(provider.models.first.recommended, isTrue, reason: provider.id);
      }
    });
  });
}
