import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/ask/models/ask_context.dart';
import 'package:personaltskmng/ask/models/ask_preset.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';

void main() {
  const bare = AskContext(ayah: AyahRef(2, 255), arabic: 'x');
  const full = AskContext(
    ayah: AyahRef(2, 255),
    arabic: 'x',
    words: ['a = b'],
    tafsirText: 'a passage',
  );

  group('AskPreset.isAvailable', () {
    test('none is available without an ayah', () {
      for (final p in AskPreset.all) {
        expect(p.isAvailable(null), isFalse, reason: p.id.name);
      }
    });

    test('tafsir and word presets wait for their text', () {
      AskPreset byId(AskPresetId id) =>
          AskPreset.all.firstWhere((p) => p.id == id);

      expect(byId(AskPresetId.explainSimply).isAvailable(bare), isTrue);
      expect(byId(AskPresetId.simplifyTafsir).isAvailable(bare), isFalse);
      expect(byId(AskPresetId.wordsGrammar).isAvailable(bare), isFalse);
      expect(byId(AskPresetId.simplifyTafsir).isAvailable(full), isTrue);
      expect(byId(AskPresetId.wordsGrammar).isAvailable(full), isTrue);
    });

    test('every preset has an id of its own and something to say', () {
      expect(
        {for (final p in AskPreset.all) p.id}.length,
        AskPreset.all.length,
      );
      for (final p in AskPreset.all) {
        expect(p.instruction.trim(), isNotEmpty);
      }
    });
  });

  test('every follow-up has its own instruction', () {
    expect(
      {for (final f in AskFollowUp.values) f.instruction}.length,
      AskFollowUp.values.length,
    );
  });
}
