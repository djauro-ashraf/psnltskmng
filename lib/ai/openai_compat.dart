import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:personaltskmng/ai/ai_chat_provider.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/http_post.dart';

/// What makes one OpenAI-style provider different from another: where it is,
/// what it is called, and the few extras it wants. Everything else (the shape
/// of the request, JSON mode, streaming, the errors) is the same for all of
/// them, so a new provider of this kind is a [OpenAiCompatSpec] and nothing
/// more. Pure Dart.
final class OpenAiCompatSpec {
  const OpenAiCompatSpec({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.defaultModel,
    this.headers = const {},
    this.extraBody = const {},
    this.jsonMode = true,
  });

  /// The provider's stable id: also the key under which its API key is kept.
  final String id;

  /// The provider's own brand name, as it is written in error messages.
  final String name;

  /// The address the `/chat/completions` path is added to.
  final String baseUrl;
  final String defaultModel;

  /// Headers sent beside the `Authorization: Bearer <key>` one.
  final Map<String, String> headers;

  /// Fields added to every request body (the provider's own options).
  final Map<String, Object?> extraBody;

  /// Whether the JSON mode field (`response_format`) is sent. A provider that
  /// does not know it for every model is left without: the prompt asks for
  /// JSON and the reader copes with what comes back.
  final bool jsonMode;

  OpenAiCompatSpec withBaseUrl(String url) => OpenAiCompatSpec(
    id: id,
    name: name,
    baseUrl: url,
    defaultModel: defaultModel,
    headers: headers,
    extraBody: extraBody,
    jsonMode: jsonMode,
  );
}

/// GitHub Models: free for every GitHub account, with a personal access token
/// that has the `models:read` permission. A request may carry 8,000 tokens in
/// and 4,000 out on the free plan, so a short prompt is not a nicety there.
const OpenAiCompatSpec githubModelsSpec = OpenAiCompatSpec(
  id: 'github',
  name: 'GitHub Models',
  baseUrl: 'https://models.github.ai/inference',
  defaultModel: 'openai/gpt-4.1-mini',
  headers: {'X-GitHub-Api-Version': '2022-11-28'},
);

/// OpenRouter: one key for many models, the ones whose id ends in `:free` at no
/// cost. Some hosts of free models keep and train on prompts, and what this app
/// sends is personal, so every request refuses those hosts
/// (`data_collection: deny`): a model that has only such hosts answers with an
/// error, and another model is then to be chosen.
const OpenAiCompatSpec openRouterSpec = OpenAiCompatSpec(
  id: 'openrouter',
  name: 'OpenRouter',
  baseUrl: 'https://openrouter.ai/api/v1',
  defaultModel: 'google/gemma-4-31b-it:free',
  extraBody: {
    'provider': {'data_collection': 'deny'},
  },
);

/// Cloudflare Workers AI, for **one job only**: sorting requests (see
/// `AgentRouter`). 10,000 "neurons" a day are free on every account with no card;
/// the lightest model costs about one neuron for a sort, so a day holds some
/// thousands of them, on a quota that is nobody else's. The model is IBM
/// Granite 4.0 micro: small, not a thinking model, and it lists Arabic, French
/// and English among its languages. JSON mode is not asked for (not every
/// model has it).
///
/// Two things are kept for it, each in its own field in Settings: the API token
/// (under [cloudflareRouterSpec]'s id) and the account id
/// ([CloudflareRouterProvider.accountKey]), which is part of the address.
const OpenAiCompatSpec cloudflareRouterSpec = OpenAiCompatSpec(
  id: 'cloudflare',
  name: 'Cloudflare',
  baseUrl: 'https://api.cloudflare.com/client/v4/accounts',
  defaultModel: '@cf/ibm-granite/granite-4.0-h-micro',
  jsonMode: false,
);

/// [OpenAiCompatProvider] for [cloudflareRouterSpec].
final class CloudflareRouterProvider extends OpenAiCompatProvider {
  CloudflareRouterProvider({
    required super.keys,
    super.client,
    super.model,
    super.timeout,
  }) : super(spec: cloudflareRouterSpec);

  /// The name under which the account id is kept (the token is kept under the
  /// provider's id, `cloudflare`).
  static const String accountKey = 'cloudflare_account';

  /// Whether [account] can stand in the address: letters and digits only (a
  /// Cloudflare account id is 32 of them), so that nothing else can be put in
  /// the path.
  static bool isValidAccount(String account) =>
      RegExp(r'^[A-Za-z0-9]+$').hasMatch(account);

  @override
  Future<Uri> chatUri(String key) async {
    final stored = await keys.read(accountKey);
    final account = stored?.trim() ?? '';
    if (account.isEmpty) {
      throw const AiProviderException(
        AiErrorKind.missingKey,
        'No Cloudflare account id stored',
      );
    }
    if (!isValidAccount(account)) {
      throw const AiProviderException(
        AiErrorKind.missingKey,
        'The Cloudflare account id has only letters and digits',
      );
    }
    return Uri.parse('${spec.baseUrl}/$account/ai/v1/chat/completions');
  }
}

/// The text of the first choice of a chat-completions answer, or null.
String? _firstContent(Object? decoded) {
  if (decoded is! Map) return null;
  final choices = decoded['choices'];
  if (choices is! List || choices.isEmpty) return null;
  final first = choices.first;
  final message = first is Map ? first['message'] : null;
  final content = message is Map ? message['content'] : null;
  return content is String && content.trim().isNotEmpty ? content : null;
}

Future<String> _key(ApiKeyStore keys, OpenAiCompatSpec spec) async {
  final key = await keys.read(spec.id);
  if (key == null || key.trim().isEmpty) {
    throw AiProviderException(
      AiErrorKind.missingKey,
      'No ${spec.name} API key stored',
    );
  }
  return key.trim();
}

List<Map<String, String>> _wire(String system, List<AiMessage> messages) => [
  {'role': 'system', 'content': system},
  for (final m in messages)
    {
      'role': m.role == AiRole.user ? 'user' : 'assistant',
      'content': m.text,
    },
];

/// An OpenAI-style chat endpoint in JSON mode (`response_format: json_object`,
/// which wants the word "JSON" in the prompt; the prompts have it). A model
/// that does not know the field ignores it, and the parser copes with a fence
/// or a word around the object.
class OpenAiCompatProvider implements AiProvider {
  OpenAiCompatProvider({
    required this.spec,
    required this.keys,
    http.Client? client,
    String? model,
    this.timeout = const Duration(seconds: 30),
  }) : model = model ?? spec.defaultModel,
       _client = client ?? http.Client();

  final OpenAiCompatSpec spec;
  final ApiKeyStore keys;
  final String model;
  final Duration timeout;
  final http.Client _client;

  @override
  String get id => spec.id;

  /// The address of the chat endpoint. Fixed for most providers; one that puts
  /// something of the user's in the address (Cloudflare: the account) reads it
  /// from the store.
  Future<Uri> chatUri(String key) async =>
      Uri.parse('${spec.baseUrl}/chat/completions');

  @override
  Future<String> generateJson({
    required String system,
    required List<AiMessage> messages,
  }) async {
    final key = await _key(keys, spec);
    final decoded = await postJson(
      client: _client,
      uri: await chatUri(key),
      headers: {...spec.headers, 'Authorization': 'Bearer $key'},
      timeout: timeout,
      name: spec.name,
      body: {
        'model': model,
        'temperature': 0.2,
        if (spec.jsonMode) 'response_format': {'type': 'json_object'},
        'messages': _wire(system, messages),
        ...spec.extraBody,
      },
    );
    final content = _firstContent(decoded);
    if (content != null) return content;
    throw AiProviderException(
      AiErrorKind.emptyResponse,
      '${spec.name} returned no message content',
    );
  }
}

/// An OpenAI-style chat endpoint as plain text, whole or streamed.
class OpenAiCompatChat implements AiChatProvider {
  OpenAiCompatChat({
    required this.spec,
    required this.keys,
    http.Client? client,
    String? model,
    this.timeout = const Duration(seconds: 60),
  }) : model = model ?? spec.defaultModel,
       _client = client ?? http.Client();

  /// How long a stream may say nothing before it is taken for lost.
  static const Duration streamIdleTimeout = Duration(seconds: 45);

  final OpenAiCompatSpec spec;
  final ApiKeyStore keys;
  final String model;
  final Duration timeout;
  final http.Client _client;

  @override
  String get id => spec.id;

  Map<String, dynamic> _payload(
    String system,
    List<AiMessage> messages, {
    bool stream = false,
  }) => {
    'model': model,
    'temperature': 0.4,
    if (stream) 'stream': true,
    'messages': _wire(system, messages),
    ...spec.extraBody,
  };

  @override
  Future<String> generateText({
    required String system,
    required List<AiMessage> messages,
  }) async {
    final key = await _key(keys, spec);
    final decoded = await postJson(
      client: _client,
      uri: Uri.parse('${spec.baseUrl}/chat/completions'),
      headers: {...spec.headers, 'Authorization': 'Bearer $key'},
      timeout: timeout,
      name: spec.name,
      body: _payload(system, messages),
    );
    final content = _firstContent(decoded);
    if (content != null) return content;
    throw AiProviderException(
      AiErrorKind.emptyResponse,
      '${spec.name} returned no message content',
    );
  }

  static String? _deltaText(Object? decoded) {
    if (decoded is! Map) return null;
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    final delta = first is Map ? first['delta'] : null;
    final text = delta is Map ? delta['content'] : null;
    return text is String ? text : null;
  }

  @override
  Stream<String> streamText({
    required String system,
    required List<AiMessage> messages,
  }) async* {
    final key = await _key(keys, spec);

    final request = http.Request(
      'POST',
      Uri.parse('${spec.baseUrl}/chat/completions'),
    );
    request.headers.addAll({
      'Content-Type': 'application/json',
      ...spec.headers,
      'Authorization': 'Bearer $key',
    });
    request.body = jsonEncode(_payload(system, messages, stream: true));

    final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(timeout);
    } on TimeoutException {
      throw AiProviderException(AiErrorKind.timeout, '${spec.name} timed out');
    } on Exception catch (e) {
      throw AiProviderException(
        AiErrorKind.network,
        '${spec.name} request failed: $e',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 429) {
        throw const AiProviderException(
          AiErrorKind.rateLimited,
          'Rate limit reached. Please wait a moment before trying again.',
          statusCode: 429,
        );
      }
      final body = await response.stream.bytesToString();
      final short = body.length > 200 ? body.substring(0, 200) : body;
      throw AiProviderException(
        AiErrorKind.http,
        '${spec.name} HTTP ${response.statusCode}: $short',
        statusCode: response.statusCode,
      );
    }

    // A stream that says nothing for a while is a connection that is gone: the
    // reader would wait for ever (the Stop button is the only way out).
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(
          streamIdleTimeout,
          onTimeout: (sink) {
            sink.addError(
              AiProviderException(
                AiErrorKind.timeout,
                '${spec.name} stopped answering',
              ),
            );
            sink.close();
          },
        );

    try {
      await for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        final content = trimmed.substring(5).trim();
        if (content == '[DONE]') break;
        if (content.isEmpty) continue;
        final Object? decoded;
        try {
          decoded = jsonDecode(content);
        } catch (_) {
          continue; // Skip unparseable SSE line
        }
        final text = _deltaText(decoded);
        if (text != null && text.isNotEmpty) yield text;
      }
    } on AiProviderException {
      rethrow;
    } on Exception catch (e) {
      // The connection broke while the answer was coming.
      throw AiProviderException(
        AiErrorKind.network,
        '${spec.name} connection lost: $e',
      );
    }
  }
}
