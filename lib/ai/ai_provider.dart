enum AiRole { user, assistant }

final class AiMessage {
  const AiMessage(this.role, this.text);

  final AiRole role;
  final String text;
}

enum AiErrorKind { missingKey, network, timeout, http, emptyResponse }

final class AiProviderException implements Exception {
  const AiProviderException(this.kind, this.message, {this.statusCode});

  final AiErrorKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'AiProviderException(${kind.name}): $message';
}

/// One LLM backend in JSON-output mode. Returns the model's raw text; parsing
/// and validation are not its job. Must never put an API key in an exception.
abstract interface class AiProvider {
  /// Stable id: also the key under which its API key is stored.
  String get id;

  Future<String> generateJson({
    required String system,
    required List<AiMessage> messages,
  });
}
