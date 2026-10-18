import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';

/// Storage shape of [AppSettings]. Never leaves the data layer.
class SettingsModel {
  const SettingsModel({
    required this.themeMode,
    this.localeCode,
    this.aiEnabled = false,
    this.aiProvider = 'gemini',
    this.aiModels = const {},
    this.backupFrequency = 'daily',
    this.googleDriveConnected = false,
    this.googleDriveEmail,
    this.lastBackupTime,
  });

  final String themeMode;
  final String? localeCode;
  final bool aiEnabled;
  final String aiProvider;
  final Map<String, String> aiModels;
  final String backupFrequency;
  final bool googleDriveConnected;
  final String? googleDriveEmail;
  final String? lastBackupTime;

  factory SettingsModel.fromJson(Map<String, dynamic> json) => SettingsModel(
    themeMode: json['themeMode'] as String? ?? AppThemeMode.system.name,
    localeCode: json['localeCode'] as String?,
    aiEnabled: json['aiEnabled'] as bool? ?? false,
    aiProvider: json['aiProvider'] as String? ?? 'gemini',
    aiModels: {
      for (final e in (json['aiModels'] as Map<String, dynamic>? ?? {}).entries)
        if (e.value is String) e.key: e.value as String,
    },
    backupFrequency: json['backupFrequency'] as String? ?? 'daily',
    googleDriveConnected: json['googleDriveConnected'] as bool? ?? false,
    googleDriveEmail: json['googleDriveEmail'] as String?,
    lastBackupTime: json['lastBackupTime'] as String?,
  );

  factory SettingsModel.fromEntity(AppSettings settings) => SettingsModel(
    themeMode: settings.themeMode.name,
    localeCode: settings.localeCode,
    aiEnabled: settings.aiEnabled,
    aiProvider: settings.aiProvider,
    aiModels: settings.aiModels,
    backupFrequency: settings.backupFrequency,
    googleDriveConnected: settings.googleDriveConnected,
    googleDriveEmail: settings.googleDriveEmail,
    lastBackupTime: settings.lastBackupTime,
  );

  Map<String, dynamic> toJson() => {
    'themeMode': themeMode,
    'localeCode': localeCode,
    'aiEnabled': aiEnabled,
    'aiProvider': aiProvider,
    'aiModels': aiModels,
    'backupFrequency': backupFrequency,
    'googleDriveConnected': googleDriveConnected,
    'googleDriveEmail': googleDriveEmail,
    'lastBackupTime': lastBackupTime,
  };

  AppSettings toEntity() => AppSettings(
    themeMode:
        AppThemeMode.values.asNameMap()[themeMode] ?? AppThemeMode.system,
    localeCode: localeCode,
    aiEnabled: aiEnabled,
    aiProvider: aiProvider,
    aiModels: aiModels,
    backupFrequency: backupFrequency,
    googleDriveConnected: googleDriveConnected,
    googleDriveEmail: googleDriveEmail,
    lastBackupTime: lastBackupTime,
  );
}
