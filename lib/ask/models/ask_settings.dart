import 'dart:convert';

/// Settings for Ask AI (Quran Study Assistant).
final class AskSettings {
  const AskSettings({
    this.enabled = false,
    this.provider = 'gemini',
    this.models = const {},
    this.answerLanguage = 'auto',
    this.answerLength = 'normal',
  });

  final bool enabled;
  final String provider;
  final Map<String, String> models;
  final String answerLanguage; // 'auto', 'en', 'fr', 'ar'
  final String answerLength; // 'normal', 'short'

  AskSettings copyWith({
    bool? enabled,
    String? provider,
    Map<String, String>? models,
    String? answerLanguage,
    String? answerLength,
  }) {
    return AskSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      models: models ?? this.models,
      answerLanguage: answerLanguage ?? this.answerLanguage,
      answerLength: answerLength ?? this.answerLength,
    );
  }

  String encode() => jsonEncode({
        'enabled': enabled,
        'provider': provider,
        'models': models,
        'answerLanguage': answerLanguage,
        'answerLength': answerLength,
      });

  factory AskSettings.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const AskSettings();
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        final rawModels = map['models'];
        final models = <String, String>{};
        if (rawModels is Map) {
          for (final e in rawModels.entries) {
            if (e.key is String && e.value is String) {
              models[e.key as String] = e.value as String;
            }
          }
        }
        return AskSettings(
          enabled: map['enabled'] as bool? ?? false,
          provider: map['provider'] as String? ?? 'gemini',
          models: models,
          answerLanguage: map['answerLanguage'] as String? ?? 'auto',
          answerLength: map['answerLength'] as String? ?? 'normal',
        );
      }
    } catch (_) {}
    return const AskSettings();
  }
}

