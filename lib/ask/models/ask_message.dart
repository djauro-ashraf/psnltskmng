import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ask/models/ask_context.dart';

/// One turn in an Ask AI chat thread.
final class AskMessage {
  const AskMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.interrupted = false,
    this.context,
  });

  final String id;
  final AiRole role;
  final String text;
  final DateTime createdAt;
  final bool interrupted;

  /// Optional context attached with this specific message.
  final AskContext? context;

  AskMessage copyWith({
    String? text,
    bool? interrupted,
    AskContext? context,
  }) {
    return AskMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      createdAt: createdAt,
      interrupted: interrupted ?? this.interrupted,
      context: context ?? this.context,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        if (interrupted) 'interrupted': interrupted,
        if (context != null) 'context': context!.toJson(),
      };

  factory AskMessage.fromJson(Map<String, dynamic> json) {
    final roleName = json['role'] as String? ?? 'user';
    final role = roleName == 'assistant' ? AiRole.assistant : AiRole.user;
    final rawDate = json['createdAt'] as String?;
    final date = rawDate != null ? DateTime.tryParse(rawDate) : null;
    final rawCtx = json['context'];

    return AskMessage(
      id: json['id'] as String? ?? '',
      role: role,
      text: json['text'] as String? ?? '',
      createdAt: date ?? DateTime.now(),
      interrupted: json['interrupted'] as bool? ?? false,
      context: rawCtx is Map<String, dynamic>
          ? AskContext.fromJson(rawCtx)
          : null,
    );
  }
}

