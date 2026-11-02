import 'dart:convert';
import 'dart:io';

import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';
import 'package:personaltskmng/quran_data/models/tafsir.dart';

/// Reads downloaded Tafsir packs from [DirectoryPackStorage].
class StorageTafsirContent implements TafsirContent {
  StorageTafsirContent(this.storage);

  final DirectoryPackStorage storage;
  final Map<String, _SourceData> _cache = {};

  @override
  Future<List<TafsirSource>> installed() async {
    final packs = await storage.installed();
    return [
      for (final p in packs)
        if (p.kind == QuranPackKind.tafsir)
          TafsirSource(id: p.id, title: p.title),
    ];
  }

  @override
  Future<AyahRange?> coverOf(String sourceId, AyahRef ayah) async {
    final source = await _load(sourceId);
    return source?.coverOf(ayah);
  }

  @override
  Future<TafsirLookup?> lookup(String sourceId, AyahRef ayah) async {
    final source = await _load(sourceId);
    return source?.lookup(ayah);
  }

  @override
  Future<TafsirPassage?> next(String sourceId, TafsirPassage from) async {
    final source = await _load(sourceId);
    return source?.next(from);
  }

  @override
  Future<TafsirPassage?> previous(String sourceId, TafsirPassage from) async {
    final source = await _load(sourceId);
    return source?.previous(from);
  }

  Future<_SourceData?> _load(String sourceId) async {
    final cached = _cache[sourceId];
    if (cached != null) return cached;

    List<int>? bytes;
    for (final path in [
      '$sourceId.json',
      'tafsir/$sourceId.json',
      '$sourceId.json.gz',
      '$sourceId.jsonl.gz',
    ]) {
      bytes = await storage.read(path);
      if (bytes != null) {
        if (path.endsWith('.gz')) {
          bytes = gzip.decode(bytes);
        }
        break;
      }
    }

    if (bytes == null) return null;

    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) return null;
      final source = _SourceData.parse(sourceId, decoded);
      _cache[sourceId] = source;
      return source;
    } catch (_) {
      return null;
    }
  }
}

class _SourceData {
  _SourceData({
    required this.sourceId,
    required this.passages,
    required this.passageIndexByAyah,
    required this.indexByStartRef,
  });

  final String sourceId;
  final List<_PassageEntry> passages;
  final Map<AyahRef, int> passageIndexByAyah;
  final Map<AyahRef, int> indexByStartRef;

  factory _SourceData.parse(String sourceId, Map<String, dynamic> raw) {
    final passages = <_PassageEntry>[];
    final passageIndexByAyah = <AyahRef, int>{};
    final indexByStartRef = <AyahRef, int>{};

    // First pass: locate all passages that define text.
    final textByStart = <AyahRef, String>{};
    for (final entry in raw.entries) {
      final ref = AyahRef.tryParse(entry.key);
      if (ref == null) continue;
      final val = entry.value;
      if (val is Map<String, dynamic> && val['text'] is String) {
        textByStart[ref] = val['text'] as String;
      } else if (val is String && !val.contains(':')) {
        // Direct string text (not a reference to another ayah)
        textByStart[ref] = val;
      }
    }

    // Second pass: map each ayah in Quran sequence to its passage.
    AyahRef? currentStart;
    int? currentIdx;

    for (var i = 0; i < QuranDivisions.ayahCount; i++) {
      final ayah = QuranDivisions.fromIndex(i);
      final rawVal = raw[ayah.key];

      if (rawVal == null) {
        // Ayah omitted in this source: close current passage if any.
        currentStart = null;
        currentIdx = null;
        continue;
      }

      if (rawVal is Map || (rawVal is String && !rawVal.contains(':'))) {
        // Starts a new passage
        final text = textByStart[ayah] ?? '';
        final passage = _PassageEntry(first: ayah, last: ayah, rawText: text);
        passages.add(passage);
        final idx = passages.length - 1;
        currentStart = ayah;
        currentIdx = idx;
        passageIndexByAyah[ayah] = idx;
        indexByStartRef[ayah] = idx;
      } else if (rawVal is String && rawVal.contains(':')) {
        // Points to an earlier ayah (passage start)
        final targetRef = AyahRef.tryParse(rawVal);
        if (targetRef != null) {
          if (currentStart == targetRef && currentIdx != null) {
            passages[currentIdx].last = ayah;
            passageIndexByAyah[ayah] = currentIdx;
          } else {
            final existingIdx = indexByStartRef[targetRef];
            if (existingIdx != null) {
              passages[existingIdx].last = ayah;
              passageIndexByAyah[ayah] = existingIdx;
              currentStart = targetRef;
              currentIdx = existingIdx;
            }
          }
        }
      }
    }

    return _SourceData(
      sourceId: sourceId,
      passages: passages,
      passageIndexByAyah: passageIndexByAyah,
      indexByStartRef: indexByStartRef,
    );
  }

  AyahRange? coverOf(AyahRef ayah) {
    final idx = passageIndexByAyah[ayah];
    return idx == null ? null : passages[idx].covers;
  }

  TafsirLookup? lookup(AyahRef ayah) {
    final idx = passageIndexByAyah[ayah];
    if (idx != null) {
      return TafsirLookup(passage: _toPassage(passages[idx]), exact: true);
    }
    if (passages.isEmpty) return null;

    // Find nearest passage
    var nearest = passages.first;
    var minDiff = (passages.first.first.index - ayah.index).abs();
    for (final p in passages) {
      final diff = (p.first.index - ayah.index).abs();
      if (diff < minDiff) {
        minDiff = diff;
        nearest = p;
      }
    }
    return TafsirLookup(passage: _toPassage(nearest), exact: false);
  }

  TafsirPassage? next(TafsirPassage from) {
    final idx = indexByStartRef[from.covers.first];
    if (idx == null || idx + 1 >= passages.length) return null;
    return _toPassage(passages[idx + 1]);
  }

  TafsirPassage? previous(TafsirPassage from) {
    final idx = indexByStartRef[from.covers.first];
    if (idx == null || idx <= 0) return null;
    return _toPassage(passages[idx - 1]);
  }

  TafsirPassage _toPassage(_PassageEntry entry) => TafsirPassage(
    sourceId: sourceId,
    covers: entry.covers,
    paragraphs: entry.paragraphs,
  );
}

class _PassageEntry {
  _PassageEntry({
    required this.first,
    required this.last,
    required this.rawText,
  });

  final AyahRef first;
  AyahRef last;
  final String rawText;
  List<String>? _paragraphs;

  AyahRange get covers => AyahRange(first, last);

  List<String> get paragraphs => _paragraphs ??= _parseParagraphs(rawText);

  static final RegExp _breakTagRegex = RegExp(r'<br\s*/?>', caseSensitive: false);
  static final RegExp _blockTagRegex = RegExp(
    r'</(p|div|h[1-6]|blockquote|li|tr|section|article)>|<hr\s*/?>',
    caseSensitive: false,
  );
  static final RegExp _tagRegex = RegExp(r'<[^>]+>');
  static final RegExp _spacesRegex = RegExp(r'[ \t\r\f\v]+');

  static List<String> _parseParagraphs(String htmlText) {
    if (htmlText.isEmpty) return const [];

    final withBreaks = htmlText
        .replaceAll(_breakTagRegex, '\n')
        .replaceAll(_blockTagRegex, '\n\n');
    final stripped = withBreaks.replaceAll(_tagRegex, '');

    final result = <String>[];
    for (final line in stripped.split('\n')) {
      final clean = _unescapeHtml(line.replaceAll(_spacesRegex, ' ').trim());
      if (clean.isNotEmpty) {
        result.add(clean);
      }
    }

    return result;
  }

  static String _unescapeHtml(String text) {
    if (!text.contains('&')) return text;
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&hellip;', '…')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m[1]!)),
        )
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'),
          (m) => String.fromCharCode(int.parse(m[1]!, radix: 16)),
        );
  }
}
