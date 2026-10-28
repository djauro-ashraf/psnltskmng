import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/quran_data/models/footnote_text.dart';

void main() {
  group('FootnoteText.parse', () {
    test('splits the text at its footnote markers', () {
      final parts = FootnoteText.parse(
        'In the name of Allāh,<sup foot_note="226402">1</sup> the Merciful.'
        '<sup foot_note="226403">2</sup>',
      );
      expect(parts, hasLength(4));
      expect((parts[0] as PlainPart).text, 'In the name of Allāh,');
      expect((parts[1] as FootnotePart).id, '226402');
      expect((parts[1] as FootnotePart).label, '1');
      expect((parts[2] as PlainPart).text, ' the Merciful.');
      expect((parts[3] as FootnotePart).id, '226403');
      expect((parts[3] as FootnotePart).label, '2');
    });

    test('a text without markers is one plain part', () {
      final parts = FootnoteText.parse('Praise be to Allah.');
      expect(parts, hasLength(1));
      expect((parts.single as PlainPart).text, 'Praise be to Allah.');
    });

    test('an empty text has no parts', () {
      expect(FootnoteText.parse(''), isEmpty);
    });

    test('a marker at the very start, and two together', () {
      final parts = FootnoteText.parse(
        '<sup foot_note="1">a</sup><sup foot_note="2">b</sup>text',
      );
      expect(parts.map((p) => p.runtimeType), [
        FootnotePart,
        FootnotePart,
        PlainPart,
      ]);
    });

    test('something that only looks like a marker stays text', () {
      final parts = FootnoteText.parse('x <sup>2</sup> y');
      expect(parts, hasLength(1));
      expect((parts.single as PlainPart).text, 'x <sup>2</sup> y');
    });
  });

  test('plain gives the text without its markers', () {
    expect(
      FootnoteText.plain('A<sup foot_note="1">1</sup> b<sup foot_note="2">2</sup>'),
      'A b',
    );
  });
}
