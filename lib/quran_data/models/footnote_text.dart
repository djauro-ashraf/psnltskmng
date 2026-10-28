/// A piece of a translation: plain text, or a footnote marker.
sealed class TextPart {
  const TextPart();
}

final class PlainPart extends TextPart {
  const PlainPart(this.text);

  final String text;
}

/// A footnote marker: the little raised number after a word. [id] finds the
/// footnote, [label] is what is printed (`1`).
final class FootnotePart extends TextPart {
  const FootnotePart(this.id, this.label);

  final String id;
  final String label;
}

/// Splits a translation into text and footnote markers. The markers are written
/// the way QUL writes them: `<sup foot_note="226402">1</sup>`. Pure Dart.
abstract final class FootnoteText {
  static final RegExp _marker = RegExp(
    r'<sup foot_note="([^"]+)">([^<]*)</sup>',
  );

  static List<TextPart> parse(String text) {
    final parts = <TextPart>[];
    var from = 0;
    for (final match in _marker.allMatches(text)) {
      if (match.start > from) {
        parts.add(PlainPart(text.substring(from, match.start)));
      }
      parts.add(FootnotePart(match.group(1)!, match.group(2)!));
      from = match.end;
    }
    if (from < text.length) parts.add(PlainPart(text.substring(from)));
    return parts;
  }

  /// The text without its markers.
  static String plain(String text) => text.replaceAll(_marker, '');
}
