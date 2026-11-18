import 'package:personaltskmng/domain/reference/quran_divisions.dart';

/// A piece of an answer: plain, bold or italic text, or a reference like [2:255]
/// (which the screen shows as a chip that opens the ayah).
final class AskSegment {
  const AskSegment(this.text, {this.bold = false, this.italic = false, this.ref});

  final String text;
  final bool bold;
  final bool italic;

  /// Set for a reference; [text] is then its form as written ("[2:255]").
  final AyahRef? ref;

  @override
  bool operator ==(Object other) =>
      other is AskSegment &&
      other.text == text &&
      other.bold == bold &&
      other.italic == italic &&
      other.ref == ref;

  @override
  int get hashCode => Object.hash(text, bold, italic, ref);

  @override
  String toString() =>
      'AskSegment($text${bold ? ', bold' : ''}${italic ? ', italic' : ''}'
      '${ref == null ? '' : ', ${ref!.key}'})';
}

/// The little of Markdown the models write: `**bold**`, `*italic*`, `# headings`
/// (shown bold), `- ` and `* ` lists (shown with a bullet), and the references
/// `[2:255]`. Nothing else is touched; a mark that never closes stays as text.
///
/// Pure: the screen turns the segments into text, the parsing is decided here.
abstract final class AskMarkdown {
  static final RegExp _heading = RegExp(r'^\s{0,3}#{1,6}\s+(.*)$');
  static final RegExp _bullet = RegExp(r'^(\s*)[*\-+]\s+(.*)$');
  static final RegExp _inline = RegExp(
    r'\*\*(.+?)\*\*|\*(?!\s)([^*\n]+?)(?<!\s)\*|\[(\d{1,3}):(\d{1,3})\]',
  );

  static List<AskSegment> parse(String text) {
    final out = <AskSegment>[];
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (i > 0) out.add(const AskSegment('\n'));
      final line = lines[i];
      final heading = _heading.firstMatch(line);
      if (heading != null) {
        out.addAll(_inlineOf(heading.group(1)!, bold: true));
        continue;
      }
      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        out.add(AskSegment('${bullet.group(1)}• '));
        out.addAll(_inlineOf(bullet.group(2)!));
        continue;
      }
      out.addAll(_inlineOf(line));
    }
    return _merged(out);
  }

  static List<AskSegment> _inlineOf(String line, {bool bold = false}) {
    final out = <AskSegment>[];
    var at = 0;
    for (final m in _inline.allMatches(line)) {
      if (m.group(3) != null) {
        final ref = AyahRef(int.parse(m.group(3)!), int.parse(m.group(4)!));
        // A bracket that is not an ayah (no 115:1, no 2:300) stays as text.
        if (!ref.isValid) continue;
        if (m.start > at) out.add(AskSegment(line.substring(at, m.start), bold: bold));
        out.add(AskSegment(m.group(0)!, bold: bold, ref: ref));
      } else {
        if (m.start > at) out.add(AskSegment(line.substring(at, m.start), bold: bold));
        final boldText = m.group(1);
        out.add(
          boldText != null
              ? AskSegment(boldText, bold: true)
              : AskSegment(m.group(2)!, bold: bold, italic: true),
        );
      }
      at = m.end;
    }
    if (at < line.length) out.add(AskSegment(line.substring(at), bold: bold));
    return out;
  }

  /// Neighbouring plain pieces of the same look are one piece.
  static List<AskSegment> _merged(List<AskSegment> segments) {
    final out = <AskSegment>[];
    for (final s in segments) {
      if (out.isNotEmpty && s.ref == null && out.last.ref == null &&
          out.last.bold == s.bold && out.last.italic == s.italic) {
        out[out.length - 1] = AskSegment(
          out.last.text + s.text,
          bold: s.bold,
          italic: s.italic,
        );
      } else {
        out.add(s);
      }
    }
    return out;
  }
}
