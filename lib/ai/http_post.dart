import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:personaltskmng/ai/ai_provider.dart';

/// POSTs JSON and returns the decoded body, mapping every failure to an
/// [AiProviderException]. Error text is trimmed and never contains headers.
Future<Object?> postJson({
  required http.Client client,
  required Uri uri,
  required Map<String, String> headers,
  required Object body,
  required Duration timeout,
  required String name,
}) async {
  final http.Response response;
  try {
    response = await client
        .post(
          uri,
          headers: {'Content-Type': 'application/json', ...headers},
          body: jsonEncode(body),
        )
        .timeout(timeout);
  } on TimeoutException {
    throw AiProviderException(AiErrorKind.timeout, '$name timed out');
  } on Exception catch (e) {
    throw AiProviderException(AiErrorKind.network, '$name request failed: $e');
  }

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final text = response.body;
    final short = text.length > 200 ? text.substring(0, 200) : text;
    throw AiProviderException(
      AiErrorKind.http,
      '$name HTTP ${response.statusCode}: $short',
      statusCode: response.statusCode,
    );
  }
  try {
    return jsonDecode(response.body);
  } on FormatException {
    throw AiProviderException(
      AiErrorKind.emptyResponse,
      '$name returned a non-JSON body',
    );
  }
}
