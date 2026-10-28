import 'dart:convert';
import 'dart:io';

import 'package:personaltskmng/mushaf/models/mushaf_page.dart';

/// The file format of the layout, words and translation packs: one JSON object
/// per line, the whole text compressed with gzip (`*.jsonl.gz`). A layout pack
/// has one line per page (line 1 is page 1, key `page`); a words or
/// translation pack has one line per s (line 1 is s 1, key `s`). A line is read
/// without decoding the others.
abstract final class PackCodec {
  static List<int> encode(List<String> lines) =>
      gzip.encode(utf8.encode(lines.join('\n')));

  static List<String> decode(List<int> compressed) =>
      const LineSplitter().convert(utf8.decode(gzip.decode(compressed)));

  /// The shape of each kind of pack: how many lines, and the key that holds
  /// the number of the line.
  static const ({int lines, String key}) pagesShape = (
    lines: MushafPage.pageCount,
    key: 'page',
  );
  static const ({int lines, String key}) surahsShape = (lines: 114, key: 's');

  /// What is wrong with a pack file, or null when it is good: [shape.lines]
  /// lines, line `n` an object whose [shape.key] is `n`.
  static String? problem(
    List<int> compressed, {
    required ({int lines, String key}) shape,
  }) {
    try {
      final lines = decode(compressed);
      if (lines.length != shape.lines) {
        return 'has ${lines.length} lines, ${shape.lines} expected';
      }
      for (var i = 0; i < lines.length; i++) {
        final object = jsonDecode(lines[i]);
        if (object is! Map || object[shape.key] != i + 1) {
          return 'line ${i + 1} is not ${shape.key} ${i + 1}';
        }
      }
      return null;
    } catch (error) {
      return 'could not be read ($error)';
    }
  }
}
