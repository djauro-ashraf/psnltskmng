import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The rule: the notes live in their own file and never influence the
/// planner. Checked on the imports, which is where an influence would start.
List<File> _dartFiles(String directory) => [
  for (final entity in Directory(directory).listSync(recursive: true))
    if (entity is File && entity.path.endsWith('.dart')) entity,
];

Iterable<String> _imports(File file) => [
  for (final line in file.readAsLinesSync())
    if (line.startsWith('import ')) line,
];

void main() {
  test('the planner, the rules and the AI never import the notes', () {
    for (final directory in ['lib/domain', 'lib/planning', 'lib/ai']) {
      for (final file in _dartFiles(directory)) {
        for (final line in _imports(file)) {
          expect(
            line.contains('personaltskmng/notes/') ||
                line.contains('features/notes'),
            isFalse,
            reason: '${file.path}: $line',
          );
        }
      }
    }
  });

  test('the notes models use no planning code at all', () {
    for (final file in _dartFiles('lib/notes/models')) {
      for (final line in _imports(file)) {
        expect(
          line.contains('personaltskmng/planning/') ||
              line.contains('personaltskmng/ai/') ||
              line.contains('domain/rules/'),
          isFalse,
          reason: '${file.path}: $line',
        );
      }
    }
  });

  test('the notes side reads only the day log and the codec helpers', () {
    const allowed = [
      'personaltskmng/planning/data/json_reader.dart',
      'personaltskmng/planning/day/day_record.dart',
      'personaltskmng/planning/models/plan_op.dart',
    ];
    for (final file in _dartFiles('lib/notes')) {
      for (final line in _imports(file)) {
        if (!line.contains('personaltskmng/planning/') &&
            !line.contains('personaltskmng/ai/') &&
            !line.contains('domain/rules/')) {
          continue;
        }
        expect(
          allowed.any(line.contains),
          isTrue,
          reason: '${file.path}: $line',
        );
      }
    }
  });

  test('the notes have a file of their own, not the Q\'s', () {
    final code = [
      for (final line in File(
        'lib/notes/data/file_note_store.dart',
      ).readAsLinesSync())
        if (!line.trimLeft().startsWith('//')) line,
    ].join('\n');
    expect(code, contains("'notes.json'"));
    expect(code, isNot(contains('state.json')));
    expect(code, isNot(contains('settings.json')));
  });
}
