import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ask/models/ask_chat.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';

/// A whole chat as plain text, to paste somewhere: the title, then each message
/// with who wrote it and at what time.
String askChatText(AskChat chat, AppLocalizations l10n) {
  String two(int n) => n.toString().padLeft(2, '0');
  final buffer = StringBuffer()
    ..writeln(chat.title)
    ..writeln('==============================');
  for (final m in chat.messages) {
    final sender = m.role == AiRole.user
        ? l10n.askRoleYou
        : l10n.askRoleAssistant;
    buffer
      ..writeln('$sender (${two(m.createdAt.hour)}:${two(m.createdAt.minute)}):')
      ..writeln(m.text)
      ..writeln();
  }
  return buffer.toString();
}
