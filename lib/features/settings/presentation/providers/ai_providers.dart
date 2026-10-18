import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/ai/api_key_store.dart';

/// Where the API keys live (secure storage in the app). Overridden in
/// app/dependencies.dart; tests use `InMemoryApiKeyStore`.
final apiKeyStoreProvider = Provider<ApiKeyStore>(
  (ref) => throw UnimplementedError('override in app/dependencies.dart'),
);

/// The AI settings the planner factory reads on the next plan. The same
/// object the factory in app/dependencies.dart was built with.
final aiRuntimeProvider = Provider<AiRuntime>(
  (ref) => throw UnimplementedError('override in app/dependencies.dart'),
);
