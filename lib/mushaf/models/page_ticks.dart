import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/mushaf/models/page_ayahs.dart';

/// What a tick on the edge of a Mushaf page marks.
enum TickKind { juz, hizb, ruku }

/// One 3 px tick on the screen edge of a Mushaf page, at the line where a juz, a
/// hizb or a ruku begins. The Mushaf has no banners (the page is a faithful
/// print), so this is all it says; tapping the tick shows its label.
///
/// A juz always begins with a hizb, so a juz tick carries its [hizb] too
/// (`Juz 15 · Hizb 29`); a hizb tick is only for the hizb that does not begin a
/// juz. Pure Dart.
final class PageTick {
  const PageTick({
    required this.line,
    required this.kind,
    required this.ayah,
    this.juz,
    this.hizb,
    this.ruku,
  });

  /// The number of the line of the page the division begins on.
  final int line;
  final TickKind kind;
  final AyahRef ayah;
  final int? juz;
  final int? hizb;
  final Ruku? ruku;
}

abstract final class PageTicks {
  /// The ticks of [page], from the ayahs it lists and the lines they begin on.
  ///
  /// [continued] says that the first ayah of the page is the end of the one that
  /// began on the page before: a division that begins at that ayah is marked on
  /// the page before, not here. (The layout of the page before tells; see
  /// `pageTicksProvider`.) The ruku ticks are all made; the screen shows them
  /// only when the reader turned "Show ruku ticks" on.
  static List<PageTick> of(MushafPage page, {bool continued = false}) {
    if (page.verses.isEmpty) return const [];
    final lines = PageAyahMap.of(page);
    final ticks = <PageTick>[];
    for (var i = 0; i < page.verses.length; i++) {
      if (i == 0 && continued) continue;
      final key = page.verses[i];
      final ayah = AyahRef.tryParse(key);
      final line = lines.firstLineOf(key);
      if (ayah == null || line == null) continue;
      final starts = QuranDivisions.startsAt(ayah);
      if (starts.juz != null) {
        ticks.add(
          PageTick(
            line: line,
            kind: TickKind.juz,
            ayah: ayah,
            juz: starts.juz,
            hizb: starts.hizb,
          ),
        );
      } else if (starts.hizb != null) {
        ticks.add(
          PageTick(
            line: line,
            kind: TickKind.hizb,
            ayah: ayah,
            hizb: starts.hizb,
          ),
        );
      }
      if (starts.ruku != null) {
        ticks.add(
          PageTick(
            line: line,
            kind: TickKind.ruku,
            ayah: ayah,
            ruku: starts.ruku,
          ),
        );
      }
    }
    return List.unmodifiable(ticks);
  }
}
