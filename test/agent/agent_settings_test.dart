import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/agent/data/agent_settings_store.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/ai/ai_models.dart';

void main() {
  test('the defaults: off, Gemini, no model typed, asks before acting', () {
    const settings = AgentSettings();
    expect(settings.enabled, isFalse);
    expect(settings.provider, 'gemini');
    expect(settings.models, isEmpty);
    expect(settings.approval, AgentApproval.ask);
    expect(settings.shareNotes, isTrue);
  });

  test('what is saved is what is read back', () {
    const settings = AgentSettings(
      enabled: true,
      provider: 'groq',
      models: {'groq': 'openai/gpt-oss-20b'},
      approval: AgentApproval.auto,
      shareNotes: false,
    );

    final back = AgentSettings.decode(settings.encode());

    expect(back.enabled, isTrue);
    expect(back.provider, 'groq');
    expect(back.models, {'groq': 'openai/gpt-oss-20b'});
    expect(back.approval, AgentApproval.auto);
    expect(back.shareNotes, isFalse);
  });

  test('nothing, an unreadable text or the wrong shape give the defaults', () {
    for (final raw in <String?>[null, '', '   ', 'not json', '[]', '42']) {
      final settings = AgentSettings.decode(raw);
      expect(settings.enabled, isFalse, reason: '$raw');
      expect(settings.approval, AgentApproval.ask, reason: '$raw');
    }
  });

  test('a field of the wrong type falls back on its own', () {
    final settings = AgentSettings.decode(
      '{"enabled":"yes","provider":7,"models":{"gemini":3,"groq":"m"},"approval":"nope","shareNotes":"x"}',
    );
    expect(settings.enabled, isFalse);
    expect(settings.provider, 'gemini');
    expect(settings.models, {'groq': 'm'});
    expect(settings.approval, AgentApproval.ask);
    expect(settings.shareNotes, isTrue);
  });

  test('the model is the one typed, else the recommended free one', () {
    final recommended = geminiModels.firstWhere((m) => m.recommended).id;
    expect(const AgentSettings().model, recommended);
    expect(
      const AgentSettings(models: {'gemini': ' my-model '}).model,
      'my-model',
    );
    expect(const AgentSettings(models: {'gemini': '  '}).model, recommended);
    expect(
      const AgentSettings(provider: 'groq').model,
      groqModels.firstWhere((m) => m.recommended).id,
    );
  });

  test('the memory store keeps the last text written', () async {
    final store = MemoryAgentSettingsStore();
    expect(store.read(), isNull);
    await store.write('x');
    expect(store.read(), 'x');
  });
}
