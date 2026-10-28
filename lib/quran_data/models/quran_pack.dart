import 'dart:convert';

import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';

/// What a downloadable pack holds.
enum QuranPackKind {
  /// The lines of the 604 pages of one mushaf edition (which word is on which
  /// line, in glyph codes) and the ayahs on each page.
  layout,

  /// The 604 page fonts of one mushaf edition (the letters of the print).
  fonts,

  /// The Unicode Arabic font (banner, basmallah, the Words view).
  textFont,

  /// The Arabic words and ayahs, and the word-by-word English. One line per s.
  words,

  /// One translation of every ayah, with its footnotes. One line per s.
  translation,
}

/// One file of a pack: where it is kept (relative to the Quran folder), where
/// it is downloaded from, and its size when known.
final class PackFile {
  const PackFile({required this.path, required this.url, this.bytes});

  final String path;
  final Uri url;
  final int? bytes;
}

/// A downloadable part of the Quran data.
final class QuranPack {
  const QuranPack({
    required this.id,
    required this.kind,
    required this.title,
    required this.files,
    this.description = '',
    this.author = '',
    this.language = '',
  });

  /// Stable, file-name safe (`layout-v2`, `words-en`, `translation-sahih`).
  final String id;
  final QuranPackKind kind;
  final String title;
  final String description;

  /// The translator, for a translation.
  final String author;

  /// The language code of a translation (`en`).
  final String language;
  final List<PackFile> files;

  /// The size when every file says it, else null.
  int? get totalBytes {
    var total = 0;
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null) return null;
      total += bytes;
    }
    return total;
  }

  @override
  bool operator ==(Object other) => other is QuranPack && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The ids the app looks for; the builder writes packs with these ids.
abstract final class QuranPackIds {
  /// The lines of the pages of an edition (`layout-v1`).
  static String layout(MushafEdition edition) => edition.layoutPackId;

  static const String words = 'words-en';
  static const String translationPrefix = 'translation-';
}

/// The list of downloadable Quran packs published at a URL (typically a GitHub release).
final class QuranManifest {
  const QuranManifest({required this.packs});

  static const int version = 1;

  final List<QuranPack> packs;

  /// Parses the `manifest.json` content and resolves all file URLs relative to [baseUri].
  factory QuranManifest.parse(String source, Uri baseUri) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } catch (e) {
      throw FormatException('not valid JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    final v = decoded['version'];
    if (v != version) {
      throw FormatException('Unsupported version $v (expected $version)');
    }
    final rawPacks = decoded['packs'];
    if (rawPacks is! List) {
      throw const FormatException('Missing "packs" list');
    }
    final seenIds = <String>{};
    final packs = <QuranPack>[];
    for (final item in rawPacks) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Pack entry must be an object');
      }
      final id = item['id'];
      if (id is! String || !RegExp(r'^[a-z0-9-]+$').hasMatch(id)) {
        throw FormatException('Bad pack id: $id');
      }
      if (!seenIds.add(id)) {
        throw FormatException('Pack "$id" appears twice');
      }
      final kindStr = item['kind'];
      final QuranPackKind kind;
      try {
        kind = QuranPackKind.values.byName(kindStr as String);
      } catch (_) {
        throw FormatException('unknown kind: $kindStr');
      }
      final title = item['title'] as String? ?? id;
      final description = item['description'] as String? ?? '';
      final author = item['author'] as String? ?? '';
      final language = item['language'] as String? ?? '';

      final fileObj = item['file'];
      final filesList = item['files'];
      final files = <PackFile>[];

      if (fileObj is Map<String, dynamic>) {
        final rawUrl = fileObj['url'];
        if (rawUrl is! String || rawUrl.isEmpty) {
          throw const FormatException('no file url');
        }
        final resolvedUrl = baseUri.resolve(rawUrl);
        final path = fileObj['path'] as String? ??
            (rawUrl.contains('://')
                ? Uri.parse(rawUrl).pathSegments.last
                : rawUrl);
        final bytes = fileObj['bytes'] as int?;
        files.add(PackFile(path: path, url: resolvedUrl, bytes: bytes));
      } else if (filesList is List && filesList.isNotEmpty) {
        for (final f in filesList) {
          if (f is! Map<String, dynamic>) continue;
          final rawUrl = f['url'];
          if (rawUrl is! String || rawUrl.isEmpty) {
            throw const FormatException('no file url');
          }
          final resolvedUrl = baseUri.resolve(rawUrl);
          final path = f['path'] as String? ??
              (rawUrl.contains('://')
                  ? Uri.parse(rawUrl).pathSegments.last
                  : rawUrl);
          final bytes = f['bytes'] as int?;
          files.add(PackFile(path: path, url: resolvedUrl, bytes: bytes));
        }
      } else {
        throw const FormatException('no file url');
      }

      packs.add(
        QuranPack(
          id: id,
          kind: kind,
          title: title,
          description: description,
          author: author,
          language: language,
          files: files,
        ),
      );
    }
    return QuranManifest(packs: packs);
  }
}
