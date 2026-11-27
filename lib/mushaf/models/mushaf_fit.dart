/// How a page is fitted to the room it has: the font size, the distance
/// between lines and the space above the first line. Pure arithmetic, so it is
/// tested without any font.
///
/// The page fonts carry their own letter shapes, so the size is found by
/// measuring: the widest line of the page, drawn at a reference size, must just
/// fill the width.
final class MushafFit {
  const MushafFit({
    required this.fontSize,
    required this.pitch,
    required this.top,
  });

  /// Nothing fits (no room, or nothing to draw).
  static const MushafFit none = MushafFit(fontSize: 0, pitch: 0, top: 0);

  /// The size of the glyphs.
  final double fontSize;

  /// The distance from one line to the next.
  final double pitch;

  /// The space above the first line, so a page shorter than the room is
  /// centered.
  final double top;

  /// A line is never closer to the next than this many font sizes ...
  static const double minPitchFactor = 1.5;

  /// ... nor farther than this many (on a tall screen the page is centered
  /// instead of stretched). Was 2.6, which on a tall phone pulled the lines
  /// well apart; the printed Madinah page sits near 2.
  static const double maxPitchFactor = 2.0;

  /// The gap kept between two words of a line, in font sizes. Stretched lines
  /// spread the room that is left evenly between their words. The widest line
  /// of a page has exactly this gap and it sets the glyph size of the whole
  /// page, so a smaller gap means bigger glyphs (was 0.1).
  static const double wordGapEm = 0.06;

  /// A hair of room on the width, so rounding never overflows a line.
  static const double widthSlack = 0.99;

  /// [widestAtRef] is the width of the widest line (its words and the gaps
  /// between them) drawn at [refSize]. [lines] is the number of lines the page
  /// has: a page with fewer than 15 (the first two) is spread over the same
  /// height as a full one.
  ///
  /// [pitchFactor] is the farthest a line may be from the next, in font sizes
  /// (the reader's choice; [maxPitchFactor] until they set it).
  static MushafFit compute({
    required double refSize,
    required double widestAtRef,
    required double width,
    required double height,
    required int lines,
    double pitchFactor = maxPitchFactor,
  }) {
    if (refSize <= 0 || widestAtRef <= 0 || width <= 0 || height <= 0) {
      return none;
    }
    if (lines <= 0) return none;

    var size = refSize * (width * widthSlack) / widestAtRef;
    var pitch = height / lines;
    // A short room: shrink the glyphs rather than crowd the lines.
    if (pitch < size * minPitchFactor) size = pitch / minPitchFactor;
    // A page with fewer lines may be spread wider than a full one.
    final spread = lines < 15 ? 15 / lines : 1.0;
    final maxPitch = size * pitchFactor * spread;
    if (pitch > maxPitch) pitch = maxPitch;
    final top = (height - pitch * lines) / 2;
    return MushafFit(fontSize: size, pitch: pitch, top: top < 0 ? 0 : top);
  }
}
