import 'package:flutter/services.dart';
import 'package:personaltskmng/mushaf/data/mushaf_source.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/quran_data/data/pack_storage.dart';
import 'package:personaltskmng/quran_data/data/quran_content.dart';
import 'package:personaltskmng/quran_data/models/quran_fonts.dart';

/// The mushaf pages read from the downloaded Quran: the lines from the layout
/// pack of the edition, the letters from the page font (registered on first
/// use). A page that is not downloaded is a state, not an error, and is not
/// remembered: after the download the same page loads.
class FileMushafSource implements MushafSource {
  FileMushafSource({
    required this._storage,
    required this._content,
  });

  final Future<DirectoryPackStorage> _storage;
  final Future<QuranContent> _content;

  /// Font families already given to the engine (it cannot take them back, and
  /// registering one twice only wastes memory).
  static final Set<String> _registered = {};

  final Map<(MushafEdition, int), MushafReady> _ready = {};

  @override
  Future<MushafPageResult> load(MushafEdition edition, int page) async {
    final cached = _ready[(edition, page)];
    if (cached != null) return cached;
    try {
      final layout = await (await _content).layoutPage(edition, page);
      if (layout == null) return const MushafNotInstalled();
      final family = edition.fontFamily(page);
      if (!await _register(family, edition.fontPath(page))) {
        return const MushafFontMissing();
      }
      return _ready[(edition, page)] = MushafReady(layout, family);
    } on FormatException catch (error) {
      return MushafBroken('p $page: ${error.message}');
    } catch (error) {
      return MushafBroken('p $page: $error');
    }
  }

  @override
  Future<String?> loadTextFont() async {
    return await _register(mushafTextFontFamily, QuranFonts.textFontPath)
        ? mushafTextFontFamily
        : null;
  }

  Future<bool> _register(String family, String path) async {
    if (_registered.contains(family)) return true;
    final bytes = await (await _storage).read(path);
    if (bytes == null) return false;
    try {
      final data = ByteData.sublistView(
        bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
      );
      final loader = FontLoader(family)..addFont(Future.value(data));
      await loader.load();
      _registered.add(family);
      return true;
    } catch (_) {
      return false;
    }
  }
}
