import 'package:personaltskmng/ask/models/ask_context.dart';
import 'package:personaltskmng/ask/models/ask_message.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';

/// Lightweight index entry for listing Ask AI chats without reading all messages.
final class AskChatHeader {
  const AskChatHeader({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.anchors = const [],
    this.snippet = '',
  });

  final String id;
  final String title;
  final DateTime updatedAt;
  final List<AyahRef> anchors;
  final String snippet;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        if (anchors.isNotEmpty) 'anchors': [for (final a in anchors) a.key],
        if (snippet.isNotEmpty) 'snippet': snippet,
      };

  factory AskChatHeader.fromJson(Map<String, dynamic> json) {
    final rawDate = json['updatedAt'] as String?;
    final date = rawDate != null ? DateTime.tryParse(rawDate) : null;
    final rawAnchors = json['anchors'];
    final anchors = <AyahRef>[];
    if (rawAnchors is List) {
      for (final a in rawAnchors) {
        if (a is String) {
          final parsed = AyahRef.tryParse(a);
          if (parsed != null) anchors.add(parsed);
        }
      }
    }

    return AskChatHeader(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      updatedAt: date ?? DateTime.now(),
      anchors: anchors,
      snippet: json['snippet'] as String? ?? '',
    );
  }
}

/// A complete Ask AI conversation thread.
final class AskChat {
  const AskChat({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.anchors = const [],
    this.pinned = const [],
    this.messages = const [],
    this.providerId = 'gemini',
    this.model = '',
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AyahRef> anchors;
  final List<AskContext> pinned;
  final List<AskMessage> messages;
  final String providerId;
  final String model;

  AskChatHeader toHeader() {
    String snippet = '';
    for (var i = messages.length - 1; i >= 0; i--) {
      final t = messages[i].text.trim();
      if (t.isNotEmpty) {
        snippet = t.length > 90 ? '${t.substring(0, 90)}…' : t;
        break;
      }
    }
    return AskChatHeader(
      id: id,
      title: title,
      updatedAt: updatedAt,
      anchors: anchors,
      snippet: snippet,
    );
  }

  AskChat copyWith({
    String? title,
    DateTime? updatedAt,
    List<AyahRef>? anchors,
    List<AskContext>? pinned,
    List<AskMessage>? messages,
    String? providerId,
    String? model,
  }) {
    return AskChat(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      anchors: anchors ?? this.anchors,
      pinned: pinned ?? this.pinned,
      messages: messages ?? this.messages,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (anchors.isNotEmpty) 'anchors': [for (final a in anchors) a.key],
        if (pinned.isNotEmpty)
          'pinned': [for (final ctx in pinned) ctx.toJson()],
        'messages': [for (final m in messages) m.toJson()],
        'providerId': providerId,
        'model': model,
      };

  factory AskChat.fromJson(Map<String, dynamic> json) {
    final rawCreated = json['createdAt'] as String?;
    final rawUpdated = json['updatedAt'] as String?;
    final created = rawCreated != null ? DateTime.tryParse(rawCreated) : null;
    final updated = rawUpdated != null ? DateTime.tryParse(rawUpdated) : null;

    final rawAnchors = json['anchors'];
    final anchors = <AyahRef>[];
    if (rawAnchors is List) {
      for (final a in rawAnchors) {
        if (a is String) {
          final parsed = AyahRef.tryParse(a);
          if (parsed != null) anchors.add(parsed);
        }
      }
    }

    final rawPinned = json['pinned'];
    final pinned = <AskContext>[];
    if (rawPinned is List) {
      for (final p in rawPinned) {
        if (p is Map<String, dynamic>) {
          pinned.add(AskContext.fromJson(p));
        }
      }
    }

    final rawMsgs = json['messages'];
    final messages = <AskMessage>[];
    if (rawMsgs is List) {
      for (final m in rawMsgs) {
        if (m is Map<String, dynamic>) {
          messages.add(AskMessage.fromJson(m));
        }
      }
    }

    return AskChat(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled',
      createdAt: created ?? DateTime.now(),
      updatedAt: updated ?? DateTime.now(),
      anchors: anchors,
      pinned: pinned,
      messages: messages,
      providerId: json['providerId'] as String? ?? 'gemini',
      model: json['model'] as String? ?? '',
    );
  }
}

