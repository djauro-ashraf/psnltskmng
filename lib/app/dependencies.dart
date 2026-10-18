import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:personaltskmng/ai/ai_runtime.dart';
import 'package:personaltskmng/ai/api_key_store.dart';
import 'package:personaltskmng/ai/secure_api_key_store.dart';
import 'package:personaltskmng/features/backup/presentation/providers/backup_providers.dart';
import 'package:personaltskmng/features/backup/services/backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_auth.dart';
import 'package:personaltskmng/features/backup/services/drive_backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_config.dart';
import 'package:personaltskmng/features/backup/services/drive_file_api.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/settings/data/datasources/settings_local_data_source.dart';
import 'package:personaltskmng/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:personaltskmng/features/settings/presentation/providers/ai_providers.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/day_log.dart';
import 'package:personaltskmng/notes/data/file_note_store.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/notes/data/preferences_note_store.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
import 'package:personaltskmng/planning/data/app_state_store.dart';
import 'package:personaltskmng/planning/data/file_app_state_store.dart';
import 'package:personaltskmng/planning/data/json_dir_day_record_store.dart';
import 'package:personaltskmng/planning/data/preferences_app_state_store.dart';
import 'package:personaltskmng/planning/day/day_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Composition root: the only place (with main.dart) that knows concrete
/// storage. Builds data sources + repositories and returns provider overrides.
/// Swapping storage = change this file only.
Future<List<Override>> buildOverrides() async {
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(),
  );

  // Planning data: preferences on web, file storage in documents directory on
  // mobile / desktop. The notes have their own file (`notes.json`) next to the
  // planning files, never inside them.
  final AppStateStore appState;
  final DayRecordStore dayRecords;
  final NoteStore noteStore;
  if (kIsWeb) {
    appState = PreferencesAppStateStore(prefs);
    dayRecords = PreferencesDayRecordStore(prefs);
    noteStore = PreferencesNoteStore(prefs);
  } else {
    final documents = await getApplicationDocumentsDirectory();
    final fileState = FileAppStateStore(documents);
    appState = fileState;
    dayRecords = JsonDirDayRecordStore(fileState.daysDirectory);
    noteStore = FileNoteStore(documents);
  }

  // AI planner: the switch, provider and model come from the app's own
  // settings; the key lives in secure storage. The factory reads the runtime
  // every time the controller builds its planner (from the next plan on).
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

  final planning = PlanningController(
    store: appState,
    dayRecords: dayRecords,
    plannerFactory: aiAwarePlannerFactory(runtime: aiRuntime, keys: keyStore),
  );
  await planning.load();

  // Notes: their own store and controller. The only thing read from the
  // planning side is the day log (the stored day records of the current Q),
  // to judge the "I remembered" taps at day end; nothing flows back.
  final notes = NotesController(
    store: noteStore,
    dayLog: dayLogReaderOf(dayRecords, () => planning.state.q.id),
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

  return [
    settingsRepositoryProvider.overrideWithValue(settingsRepo),
    planningControllerProvider.overrideWithValue(planning),
    notesControllerProvider.overrideWithValue(notes),
    apiKeyStoreProvider.overrideWithValue(keyStore),
    aiRuntimeProvider.overrideWithValue(aiRuntime),
    dayRecordStoreProvider.overrideWithValue(dayRecords),
    driveBackupServiceProvider.overrideWithValue(driveService),
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
