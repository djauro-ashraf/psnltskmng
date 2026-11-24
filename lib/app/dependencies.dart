import 'dart:io' show Directory, File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:personaltskmng/agent/controller/agent_providers.dart';
import 'package:personaltskmng/agent/data/shared_agent_settings_store.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/secure_api_key_store.dart';
import 'package:personaltskmng/ask/controller/ask_providers.dart';
import 'package:personaltskmng/ask/data/chat_store.dart';
import 'package:personaltskmng/ask/data/file_chat_store.dart';
import 'package:personaltskmng/ask/data/in_memory_chat_store.dart';
import 'package:personaltskmng/ask/data/shared_ask_settings_store.dart';
import 'package:personaltskmng/features/backup/presentation/providers/backup_providers.dart';
import 'package:personaltskmng/features/backup/services/backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_auth.dart';
import 'package:personaltskmng/features/backup/services/drive_backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_config.dart';
import 'package:personaltskmng/features/backup/services/drive_file_api.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/memo/presentation/providers/reading_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:personaltskmng/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:personaltskmng/features/settings/presentation/providers/ai_providers.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_providers.dart';
import 'package:personaltskmng/mushaf/data/shared_mushaf_edition_store.dart';
import 'package:personaltskmng/memo/controller/memo_controller.dart';
import 'package:personaltskmng/memo/controller/reading_controller.dart';
import 'package:personaltskmng/memo/data/file_reading_store.dart';
import 'package:personaltskmng/memo/data/reading_store.dart';
import 'package:personaltskmng/memo/data/file_memo_store.dart';
import 'package:personaltskmng/memo/data/memo_store.dart';
import 'package:personaltskmng/memo/data/page_map_store.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/day_log.dart';
import 'package:personaltskmng/notes/data/file_note_store.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/data/preferences_note_store.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/screen_wake.dart';
import 'package:personaltskmng/quran_data/data/file_mushaf_source.dart';
import 'package:personaltskmng/quran_data/data/shared_quran_prefs_store.dart';
import 'package:personaltskmng/quran_data/data/wakelock_screen_wake.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Composition root: the only place (with main.dart) that knows concrete
/// storage. Builds data sources + repositories and returns provider overrides.
/// Swapping storage = change this file only.
Future<List<Override>> buildOverrides() async {
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );

  // Memorisation data: preferences on web, a file (`memo.json`) in the documents
  // directory on mobile / desktop. The notes have their own file (`notes.json`)
  // next to it, never inside it. The old planner's `state.json` is only read,
  // once, to turn its history into log lines; it is left where it is.
  final MemoStore memoStore;
  final ReadingStore readingStore;
  final LegacyStateReader legacyReader;
  final NoteStore noteStore;
  final ChatStore chatStore;
  if (kIsWeb) {
    memoStore = PreferencesMemoStore(prefs);
    readingStore = PreferencesReadingStore(prefs);
    legacyReader = () async => prefs.getString('planning_state_v1');
    noteStore = PreferencesNoteStore(prefs);
    chatStore = InMemoryChatStore();
  } else {
    final documents = await getApplicationDocumentsDirectory();
    memoStore = FileMemoStore(documents);
    readingStore = FileReadingStore(documents);
    legacyReader = () async {
      final file = File('${documents.path}/state.json');
      return await file.exists() ? file.readAsString() : null;
    };
    noteStore = FileNoteStore(documents);
    chatStore = FileChatStore(Directory('${documents.path}/ask'));
  }

  // AI planner: the switch, provider and model come from the app's own
  // settings; the key lives in secure storage. The planner reads the runtime
  // every time a plan is asked for (from the next plan on).
  final settingsRepo = SettingsRepositoryImpl(SettingsLocalDataSource(prefs));
  final appSettings = settingsRepo.load();
  final ApiKeyStore keyStore = SecureApiKeyStore();
  final aiRuntime = AiRuntime(
    enabled: appSettings.aiEnabled,
    providerId: appSettings.aiProvider,
    models: appSettings.aiModels,
    providersWithKey: {
      for (final provider in aiProviderInfos)
        if (await _hasKey(keyStore, provider.id)) provider.id,
    },
  );

  final memo = MemoController(store: memoStore, legacy: legacyReader);
  await memo.load();

  // Reading evidence (the time spent on each page, for the suggested log): its
  // own file, never part of the log or of a backup.
  final reading = ReadingController(store: readingStore);
  await reading.load(
    Day.fromDateTime(DateTime.now()),
    keepDays: memo.data.settings.readKeepDays,
  );

  // Notes: their own store and controller. The only thing read from the
  // memorisation side is the log (the R of a day), to judge the "I remembered"
  // taps at day end; nothing flows back.
  final notes = NotesController(
    store: noteStore,
    dayLog: dayLogReaderOf(() => memo),
  );
  await notes.load();

  // Google Drive backup: the sign-in (refresh token in the secure store) and the
  // one backup file in the app's own hidden Drive folder. The OAuth client comes
  // from the build (--dart-define, see docs/DRIVE_SETUP.md); without it the
  // Drive backup says so instead of pretending.
  final httpClient = http.Client();
  final driveAuth = GoogleDeviceAuth(
    config: DriveConfig.fromEnvironment,
    client: httpClient,
    vault: keyStore,
  );
  final driveService = DriveBackupService(
    backupService: const BackupService(),
    prefs: prefs,
    auth: driveAuth,
    files: DriveFileApi(client: httpClient, accessToken: driveAuth.accessToken),
  );
  await _reconcileDriveSetting(settingsRepo, driveAuth);
  // A reader who never chose how to read opens in Details (the Quran view is
  // Mushaf until something says otherwise, so the first run says it here, once;
  // a choice made before is kept as it is).
  final quranPrefs = SharedQuranPrefsStore(prefs);
  if (quranPrefs.get(QuranPrefKeys.view) == null) {
    await quranPrefs.set(QuranPrefKeys.view, QuranView.details.name);
  }

  return [
    settingsRepositoryProvider.overrideWithValue(settingsRepo),
    memoControllerProvider.overrideWithValue(memo),
    readingControllerProvider.overrideWithValue(reading),
    pageMapStoreProvider.overrideWithValue(SharedPageMapStore(prefs)),
    notesControllerProvider.overrideWithValue(notes),
    apiKeyStoreProvider.overrideWithValue(keyStore),
    aiKeyStoreProvider.overrideWithValue(keyStore),
    chatStoreProvider.overrideWithValue(chatStore),
    askSettingsStoreProvider.overrideWithValue(SharedAskSettingsStore(prefs)),
    // The agent: its settings (on this device only); its key is in the secure
    // store under its own name, next to the other keys.
    agentSettingsStoreProvider.overrideWithValue(
      SharedAgentSettingsStore(prefs),
    ),
    aiRuntimeProvider.overrideWithValue(aiRuntime),
    driveBackupServiceProvider.overrideWithValue(driveService),
    // The Quran side reads the downloaded Quran; the view, the translation and
    // the pack address chosen there are kept in the app preferences too.
    quranPrefsStoreProvider.overrideWithValue(quranPrefs),
    // "Keep screen on while reading" needs the platform's wake lock.
    screenWakeProvider.overrideWithValue(const WakelockScreenWake()),
    mushafEditionStoreProvider.overrideWithValue(SharedMushafEditionStore(prefs)),
    mushafSourceProvider.overrideWith(
      (ref) => FileMushafSource(
        storage: ref.watch(quranStorageProvider.future),
        content: ref.watch(quranContentProvider.future),
      ),
    ),
  ];
}

/// The settings remember "Drive connected" for the screens, but the truth is the
/// sign-in kept on this device. The old simulated connection (an e-mail typed
/// in, nothing signed in), a restore, or a revoked sign-in can leave the two
/// apart: the settings follow the sign-in.
Future<void> _reconcileDriveSetting(
  SettingsRepositoryImpl settingsRepo,
  DriveAuth auth,
) async {
  try {
    final settings = settingsRepo.load();
    final account = await auth.account();
    final connected = account != null;
    if (settings.googleDriveConnected == connected &&
        settings.googleDriveEmail == account?.email) {
      return;
    }
    await settingsRepo.save(
      settings.copyWith(
        googleDriveConnected: connected,
        googleDriveEmail: account?.email,
      ),
    );
  } catch (_) {
    // The secure store may be unavailable on a platform: leave the setting.
  }
}

Future<bool> _hasKey(ApiKeyStore keys, String providerId) async {
  try {
    final key = await keys.read(providerId);
    return key != null && key.trim().isNotEmpty;
  } catch (_) {
    return false;
  }
}
