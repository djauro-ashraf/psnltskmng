import 'dart:convert';

import 'package:personaltskmng/ai/ai_runtime.dart';

/// Whether the agent asks before it changes anything.
enum AgentApproval {
  /// The agent shows what it is about to do and waits for a tap (the default).
  ask,

  /// The agent does it at once. Every log it writes can still be undone.
  auto;

  static AgentApproval fromName(Object? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return AgentApproval.ask;
  }
}

/// The agent's own settings: on or off, its own provider, model and approval
/// mode. Not the planner's and not the assistant's: the agent can use another
/// provider, another model and another key than both. Kept on this device (see
/// `AgentSettingsStore`), never in a backup. Pure Dart.
final class AgentSettings {
  const AgentSettings({
    this.enabled = false,
    this.provider = 'gemini',
    this.models = const {},
    this.approval = AgentApproval.ask,
    this.shareNotes = true,
  });

  final bool enabled;

  /// The id of the provider the agent calls (`gemini` or `groq`).
  final String provider;

  /// Model per provider id; a missing or empty entry means the agent's default.
  final Map<String, String> models;

  final AgentApproval approval;

  /// Whether the AI is shown the user's notes (their text, trimmed) so it can
  /// answer about them and remember, restore or delete them by id. Off: it
  /// never sees a note and can only add new ones.
  final bool shareNotes;

  /// The model the agent calls: the one typed for [provider], else the
  /// provider's recommended free model, else the provider's default.
  String get model {
    final chosen = models[provider]?.trim();
    if (chosen != null && chosen.isNotEmpty) return chosen;
    return defaultModelOf(provider);
  }

  /// What the model field falls back to for [providerId].
  static String defaultModelOf(String providerId) {
    final info = aiProviderInfo(providerId);
    for (final model in info.models) {
      if (model.recommended) return model.id;
    }
    return info.defaultModel;
  }

  AgentSettings copyWith({
    bool? enabled,
    String? provider,
    Map<String, String>? models,
    AgentApproval? approval,
    bool? shareNotes,
  }) => AgentSettings(
    enabled: enabled ?? this.enabled,
    provider: provider ?? this.provider,
    models: models ?? this.models,
    approval: approval ?? this.approval,
    shareNotes: shareNotes ?? this.shareNotes,
  );

  String encode() => jsonEncode({
    'enabled': enabled,
    'provider': provider,
    'models': models,
    'approval': approval.name,
    'shareNotes': shareNotes,
  });

  /// Reads what [encode] wrote. Anything missing or unusable falls back to the
  /// default of that field (never throws).
  factory AgentSettings.decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const AgentSettings();
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        final models = <String, String>{};
        final rawModels = map['models'];
        if (rawModels is Map) {
          for (final entry in rawModels.entries) {
            final key = entry.key;
            final value = entry.value;
            if (key is String && value is String) models[key] = value;
          }
        }
        final enabled = map['enabled'];
        final provider = map['provider'];
        return AgentSettings(
          enabled: enabled is bool ? enabled : false,
          provider: provider is String && provider.isNotEmpty
              ? provider
              : 'gemini',
          models: models,
          approval: AgentApproval.fromName(map['approval']),
          shareNotes: map['shareNotes'] is bool
              ? map['shareNotes'] as bool
              : true,
        );
      }
    } catch (_) {
      // Unreadable text: the defaults stand, the next change rewrites it.
    }
    return const AgentSettings();
  }
}
