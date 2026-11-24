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
    if (line.startsWith('import ') || line.startsWith('export ')) line,
];

void main() {
  test('the agent core imports no screen, no feature and no other module', () {
    for (final file in _dartFiles('lib/agent')) {
      for (final line in _imports(file)) {
        expect(
          line.contains('personaltskmng/features/') ||
              line.contains('personaltskmng/app/') ||
              line.contains('personaltskmng/ask/') ||
              line.contains('personaltskmng/notes/') ||
              line.contains('personaltskmng/planner/') ||
              line.contains('personaltskmng/quran_data/') ||
              line.contains('personaltskmng/mushaf/') ||
              line.contains('package:flutter/') ||
              line.contains('dart:io'),
          isFalse,
          reason: '${file.path}: forbidden import: $line',
        );
      }
    }
  });

  test('nothing but the agent, its screens and the wiring imports the agent', () {
    for (final directory in [
      'lib/ai',
      'lib/ask',
      'lib/planner',
      'lib/memo',
      'lib/domain',
      'lib/notes',
      'lib/quran_data',
      'lib/mushaf',
      'lib/core',
      'lib/shared',
    ]) {
      for (final file in _dartFiles(directory)) {
        for (final line in _imports(file)) {
          expect(
            line.contains('personaltskmng/agent/') ||
                line.contains('features/agent/'),
            isFalse,
            reason: '${file.path}: imports the agent: $line',
          );
        }
      }
    }
  });

  test('the agent has no way to read or write the planner key or the vault', () {
    // It reaches keys only through the scoped store; no file of the agent names
    // the planner's key slot or the saved-keys vault.
    for (final file in _dartFiles('lib/agent')) {
      final text = file.readAsStringSync();
      expect(text.contains('saved_ai_keys'), isFalse, reason: file.path);
      expect(text.contains('SavedKeyStore'), isFalse, reason: file.path);
      expect(text.contains('apiKeyStoreProvider'), isFalse, reason: file.path);
    }
  });

  test('the screens and the controller of the agent never touch a key', () {
    // The agent can never read, write or even name an API key: the only key it
    // meets is its own, and that is handled by its settings section alone.
    for (final file in _dartFiles('lib/features/agent')) {
      final text = file.readAsStringSync();
      for (final forbidden in [
        'apiKeyStoreProvider',
        'aiKeyStoreProvider',
        'agentKeysProvider',
        'ApiKeyStore',
        'SavedKeyStore',
        'saveKey(',
        'removeKey(',
      ]) {
        expect(text.contains(forbidden), isFalse, reason: '${file.path}: $forbidden');
      }
    }
  });

  test('the catalog has no door to a key, to the agent itself or to the pack source', () {
    final text = File('lib/agent/models/agent_catalog.dart').readAsStringSync();
    // Only the explanation of what is left out may name them.
    final code = text
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('///') && !l.trimLeft().startsWith('//'))
        .join('\n')
        .toLowerCase();
    expect(code.contains('apikey'), isFalse);
    expect(code.contains('manifest'), isFalse);
    expect(code.contains('agentapproval'), isFalse);
    expect(code.contains('sharenotes'), isFalse);
  });

  test('the agent is not part of the backup', () {
    for (final file in _dartFiles('lib/features/backup')) {
      final text = file.readAsStringSync().toLowerCase();
      expect(text.contains('agent_settings'), isFalse, reason: file.path);
      expect(text.contains('agentsettings'), isFalse, reason: file.path);
    }
  });
}
