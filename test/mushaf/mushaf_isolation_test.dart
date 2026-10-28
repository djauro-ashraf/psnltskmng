import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartFiles(String directory) => [
  for (final entity in Directory(directory).listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart')) entity,
];

Iterable<String> _imports(File file) =>
    file.readAsLinesSync().where((line) => line.startsWith('import '));

void main() {
  test('the planner, the rules, the AI and the notes never import the Quran',
      () {
    // The Quran pages, words and translations are display only: no decision,
    // no plan, no prompt and no note depends on them.
    for (final directory in [
      'lib/domain/models',
      'lib/domain/rules',
      'lib/domain/simulation',
      'lib/planning',
      'lib/ai',
      'lib/notes',
    ]) {
      for (final file in _dartFiles(directory)) {
        for (final line in _imports(file)) {
          expect(
            line.contains('personaltskmng/mushaf/') ||
                line.contains('personaltskmng/quran_data/'),
            isFalse,
            reason: '${file.path}: $line',
          );
        }
      }
    }
  });

  test('the Quran kernels import no feature', () {
    for (final directory in ['lib/mushaf', 'lib/quran_data']) {
      for (final file in _dartFiles(directory)) {
        for (final line in _imports(file)) {
          expect(
            line.contains('personaltskmng/features/'),
            isFalse,
            reason: '${file.path}: $line',
          );
        }
      }
    }
  });

  test('the mushaf kernel does not depend on the downloads', () {
    // quran_data reads the mushaf, never the other way round.
    for (final file in _dartFiles('lib/mushaf')) {
      for (final line in _imports(file)) {
        expect(
          line.contains('personaltskmng/quran_data/'),
          isFalse,
          reason: '${file.path}: $line',
        );
      }
    }
  });

  test('the pure parts of the Quran kernels import no Flutter', () {
    // They also run under `dart run tool/...` (the pack builder).
    for (final directory in ['lib/mushaf/models', 'lib/quran_data/models']) {
      for (final file in _dartFiles(directory)) {
        for (final line in _imports(file)) {
          expect(
            line.contains('package:flutter'),
            isFalse,
            reason: '${file.path}: $line',
          );
        }
      }
    }
  });
}
