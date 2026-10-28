// Builds the Quran packs the app downloads, from the QUL exports.
//
//   dart run tool/build_quran_packs.dart \
//     --layout "C:\qul\layout-qcf-v2" \
//     --word-script "C:\qul\word-script-qpc-hafs.json" \
//     --ayah-script "C:\qul\ayah-script-qpc-hafs.json" \
//     --word-translation "C:\qul\word-translation-en.json" \
//     --translation "sahih|Saheeh International|Umm Muhammad|en|C:\qul\sahih.json" \
//     --translation "pickthall|Pickthall|M. M. Pickthall|en|C:\qul\pickthall.json" \
//     --out dist
//
// --layout is the folder of the QUL "mushaf layout" JSON export (1.json to
// 604.json). The other files are QUL JSON exports too (the "simple" JSON of a
// translation, without footnotes). Writes, into --out: layout-v2.jsonl.gz,
// words-en.jsonl.gz, translation-<id>.jsonl.gz for each --translation, and
// manifest.json. Upload them all to one place (for example a GitHub release)
// and give the app the address of manifest.json. See docs/QURAN_DATA.md.
//
// Checks first that the layout is the same book as the app's page tables (the
// banner of every s on the page `STable` says), and exits with 1 on any problem.
import 'dart:convert';
import 'dart:io';

import 'package:personaltskmng/mushaf/models/mushaf_check.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/quran_data/data/pack_codec.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';
import 'package:personaltskmng/quran_data/models/quran_pack_builder.dart';

Never _fail(String message) {
  stderr.writeln('Error: $message');
  exit(1);
}

Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) _fail('File not found: $path');
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map<String, dynamic>) _fail('$path is not a JSON object');
  return decoded;
}

void main(List<String> args) {
  final single = <String, String>{};
  final translations = <String>[];
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--') || i + 1 >= args.length) {
      _fail('Unexpected argument: $arg');
    }
    final value = args[++i];
    if (arg == '--translation') {
      translations.add(value);
    } else {
      single[arg.substring(2)] = value;
    }
  }
  for (final name in ['layout', 'word-script', 'ayah-script', 'word-translation']) {
    if (!single.containsKey(name)) _fail('Missing --$name');
  }
  final out = Directory(single['out'] ?? 'dist')..createSync(recursive: true);

  // The layout: 604 page files.
  final pages = <int, Map<String, dynamic>>{};
  final layoutDir = Directory(single['layout']!);
  if (!layoutDir.existsSync()) _fail('Folder not found: ${layoutDir.path}');
  for (var p = 1; p <= MushafPage.pageCount; p++) {
    final file = File('${layoutDir.path}/$p.json');
    if (!file.existsSync()) _fail('Missing ${file.path}');
    pages[p] = _readJson(file.path);
  }

  // Same book as the app's page tables?
  final problems = MushafCheck.problems([
    for (final p in pages.values) MushafPage.fromJson(p),
  ]);
  if (problems.isNotEmpty) {
    stderr.writeln('The layout does not fit the app (${problems.length}):');
    for (final problem in problems.take(20)) {
      stderr.writeln('  - $problem');
    }
    exit(1);
  }
  stdout.writeln('Layout: 604 pages, the s table agrees.');

  final index = QulWordIndex.from(_readJson(single['word-script']!));
  final covered = QuranPackBuilder.versesCovered(pages, index);
  stdout.writeln('Ayahs on the pages: $covered of ${index.verseCount}.');
  if (covered != index.verseCount || covered != 6236) {
    _fail(
      'The pages cover $covered ayahs and the word script has '
      '${index.verseCount}; both must be 6236. Is the word script of the '
      'same QUL mushaf?',
    );
  }

  final manifest = <Map<String, Object?>>[];
  void write(String id, QuranPackKind kind, List<String> lines, Map<String, Object?> extra) {
    final bytes = PackCodec.encode(lines);
    File('${out.path}/$id.jsonl.gz').writeAsBytesSync(bytes);
    manifest.add({
      'id': id,
      'kind': kind.name,
      ...extra,
      'file': {'url': '$id.jsonl.gz', 'bytes': bytes.length},
    });
    stdout.writeln('  $id.jsonl.gz  ${(bytes.length / 1024).round()} KB');
  }

  final edition = switch (single['edition']) {
    'v2' => MushafEdition.v2,
    _ => MushafEdition.v1,
  };
  write(
    QuranPackIds.layout(edition),
    QuranPackKind.layout,
    QuranPackBuilder.layoutLines(pages),
    {'title': 'Quran pages', 'description': 'The lines of the 604 pages.'},
  );
  write(
    QuranPackIds.words,
    QuranPackKind.words,
    QuranPackBuilder.wordsLines(
      pages: pages,
      index: index,
      ayahScript: _readJson(single['ayah-script']!),
      wordTranslation: _readJson(single['word-translation']!),
    ),
    {
      'title': 'Words and Arabic text',
      'description': 'Every ayah with its words and the English of each word.',
    },
  );
  for (final spec in translations) {
    final parts = spec.split('|');
    if (parts.length != 5) {
      _fail('--translation needs "id|title|author|language|file", got: $spec');
    }
    final [id, title, author, language, path] = parts;
    if (!RegExp(r'^[a-z0-9]+$').hasMatch(id)) _fail('Bad translation id: $id');
    write(
      '${QuranPackIds.translationPrefix}$id',
      QuranPackKind.translation,
      QuranPackBuilder.translationLines(
        pages: pages,
        index: index,
        translation: _readJson(path),
      ),
      {'title': title, 'author': author, 'language': language},
    );
  }

  File('${out.path}/manifest.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'version': QuranManifest.version,
      'packs': manifest,
    }),
  );
  stdout.writeln('Done: ${out.path}/manifest.json');
}
