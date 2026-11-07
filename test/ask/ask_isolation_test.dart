import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartFiles(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) return const [];
  return [
    for (final entity in dir.listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
  ];
}

Iterable<String> _imports(File file) => [
      for (final line in file.readAsLinesSync())
        if (line.startsWith('import ')) line,
    ];

void main() {
  test('the planner, domain and rules never import ask', () {
    for (final directory in ['lib/domain', 'lib/planning', 'lib/ai']) {
      for (final file in _dartFiles(directory)) {
        for (final line in _imports(file)) {
          expect(
            line.contains('personaltskmng/ask/'),
            isFalse,
            reason: '${file.path}: $line imports ask',
          );
        }
      }
    }
  });

  test('ask never imports planning, domain rules/models, notes or planner AI', () {
    for (final file in _dartFiles('lib/ask')) {
      for (final line in _imports(file)) {
        expect(
          line.contains('personaltskmng/planning/') ||
              line.contains('personaltskmng/notes/') ||
              line.contains('domain/rules/') ||
              line.contains('domain/models/') ||
              line.contains('ai/ai_planner.dart') ||
              line.contains('ai/prompt_builder.dart') ||
              line.contains('ai/plan_parser.dart') ||
              line.contains('ai/ai_runtime.dart'),
          isFalse,
          reason: '${file.path}: forbidden import: $line',
        );
      }
    }
  });

  test('backup data has no ask or chat fields', () {
    final backupFile = File('lib/features/backup/data/backup_data.dart');
    expect(backupFile.existsSync(), isTrue);
    final content = backupFile.readAsStringSync();
    expect(content.contains('AskChat'), isFalse);
    expect(content.contains('ask/'), isFalse);
    expect(content.contains('chats'), isFalse);
  });
}

