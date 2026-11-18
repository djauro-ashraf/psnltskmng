import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/ask/prompts/ask_markdown.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';

void main() {
  group('AskMarkdown.parse', () {
    test('plain text is one piece', () {
      expect(AskMarkdown.parse('Just words.'), [const AskSegment('Just words.')]);
    });

    test('bold and italic marks are taken out of the text', () {
      expect(AskMarkdown.parse('A **strong** and *soft* word'), [
        const AskSegment('A '),
        const AskSegment('strong', bold: true),
        const AskSegment(' and '),
        const AskSegment('soft', italic: true),
        const AskSegment(' word'),
      ]);
    });

    test('a mark that never closes stays as it was written', () {
      expect(AskMarkdown.parse('2 * 3 is 6 and **open'), [
        const AskSegment('2 * 3 is 6 and **open'),
      ]);
    });

    test('references become pieces of their own', () {
      expect(AskMarkdown.parse('See [2:255] now'), [
        const AskSegment('See '),
        const AskSegment('[2:255]', ref: AyahRef(2, 255)),
        const AskSegment(' now'),
      ]);
    });

    test('a bracket that is not an ayah stays text', () {
      expect(AskMarkdown.parse('Not [115:1] nor [2:300]'), [
        const AskSegment('Not [115:1] nor [2:300]'),
      ]);
    });

    test('bold takes a reference inside it as text', () {
      final parts = AskMarkdown.parse('**Read [1:1]**');
      expect(parts, [const AskSegment('Read [1:1]', bold: true)]);
    });

    test('lists get a bullet, headings are bold', () {
      expect(AskMarkdown.parse('# Title\n- one\n* two\ntext'), [
        const AskSegment('Title', bold: true),
        const AskSegment('\n• one\n• two\ntext'),
      ]);
    });

    test('an indented list keeps its indent', () {
      expect(AskMarkdown.parse('  - nested'), [const AskSegment('  • nested')]);
    });
  });
}
