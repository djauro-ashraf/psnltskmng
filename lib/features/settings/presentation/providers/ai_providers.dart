import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/saved_key_store.dart';

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

/// The keys the user saved under a name. They live in the same secure store as
/// the active keys (so only on this device, never in the backup), which is why
/// this needs no override of its own.
final savedKeyStoreProvider = Provider<SavedKeyStore>(
  (ref) => SavedKeyStore(ref.watch(apiKeyStoreProvider)),
);
