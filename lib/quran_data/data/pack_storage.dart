import 'dart:convert';
import 'dart:io';

import 'package:personaltskmng/quran_data/models/quran_pack.dart';

/// How much of a pack is on the device.
final class PackStatus {
  const PackStatus({required this.have, required this.total});

  final int have;
  final int total;

  bool get complete => total > 0 && have >= total;
  bool get none => have == 0;
}

/// A pack that is installed, as its `.meta.json` says (so the list works
/// offline, without the manifest).
final class InstalledPack {
  const InstalledPack({
    required this.id,
    required this.kind,
    required this.title,
    this.author = '',
    this.language = '',
  });

  final String id;
  final QuranPackKind kind;
  final String title;
  final String author;
  final String language;
}

/// The Quran folder of the app (`<app support>/quran`): the downloaded packs
/// and fonts. Every write goes to a `.part` file that is renamed when whole, so
/// a download that stops never leaves half a file.
class DirectoryPackStorage {
  DirectoryPackStorage(this.root);

  final Directory root;

  File file(String path) => File('${root.path}/$path');

  Future<List<int>?> read(String path) async {
    final target = file(path);
    return target.existsSync() ? target.readAsBytes() : null;
  }

  Future<void> write(String path, List<int> bytes) async {
    final target = file(path);
    await target.parent.create(recursive: true);
    final part = File('${target.path}.part');
    await part.writeAsBytes(bytes, flush: true);
    await part.rename(target.path);
  }

  bool has(String path) {
    final target = file(path);
    return target.existsSync() && target.lengthSync() > 0;
  }

  PackStatus status(QuranPack pack) => PackStatus(
    have: pack.files.where((f) => has(f.path)).length,
    total: pack.files.length,
  );

  Future<void> delete(QuranPack pack) async {
    for (final f in pack.files) {
      final target = file(f.path);
      if (target.existsSync()) await target.delete();
    }
    final meta = file('${pack.id}.meta.json');
    if (meta.existsSync()) await meta.delete();
  }

  Future<void> writeMeta(QuranPack pack) => write(
    '${pack.id}.meta.json',
    utf8.encode(
      jsonEncode({
        'id': pack.id,
        'kind': pack.kind.name,
        'title': pack.title,
        'author': pack.author,
        'language': pack.language,
      }),
    ),
  );

  /// The packs installed completely, read from the `.meta.json` files.
  Future<List<InstalledPack>> installed() async {
    if (!root.existsSync()) return const [];
    final out = <InstalledPack>[];
    for (final entity in root.listSync()) {
      if (entity is! File || !entity.path.endsWith('.meta.json')) continue;
      try {
        final json = jsonDecode(await entity.readAsString());
        if (json is! Map<String, dynamic>) continue;
        final kind = QuranPackKind.values.asNameMap()[json['kind']];
        final id = json['id'];
        if (kind == null || id is! String) continue;
        if (!has('$id.jsonl.gz')) continue;
        out.add(
          InstalledPack(
            id: id,
            kind: kind,
            title: '${json['title'] ?? id}',
            author: '${json['author'] ?? ''}',
            language: '${json['language'] ?? ''}',
          ),
        );
      } catch (_) {
        // A damaged marker is the same as no marker.
      }
    }
    out.sort((a, b) => a.title.compareTo(b.title));
    return out;
  }
}
