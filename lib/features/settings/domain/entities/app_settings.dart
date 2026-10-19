enum AppThemeMode { system, light, dark }

/// The way the text (the pages of the book) runs on screen. The book is read
/// right to left, with page 1 on the right, so that is the default. Only
/// things drawn in text order follow it (the page strips, the page cells,
/// paging and the arrows that go with them); minutes, budgets and the rest of
/// the interface do not.
enum ReadingDirection { rightToLeft, leftToRight }

/// User preferences. Immutable value object; pure Dart.
final class AppSettings {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.localeCode,
    this.readingDirection = ReadingDirection.rightToLeft,
    this.aiEnabled = false,
    this.aiProvider = 'gemini',
    this.aiModels = const {},
    this.backupFrequency = 'daily',
    this.googleDriveConnected = false,
    this.googleDriveEmail,
    this.lastBackupTime,
  });

  final AppThemeMode themeMode;

  /// Language code such as `en` or `fr`; null follows the system language.
  final String? localeCode;

  /// How the text runs on screen; one setting for everything drawn in text
  /// order.
  final ReadingDirection readingDirection;

  /// The AI planner switch (off by default).
  final bool aiEnabled;

  /// The id of the chosen AI provider (`gemini` or `groq`).
  final String aiProvider;

  /// Model per provider id; a missing or empty entry means the provider's default.
  final Map<String, String> aiModels;

  /// Frequency of auto-backups: `manual`, `daily`, `weekly`.
  final String backupFrequency;

  /// Whether Google Drive sync is active.
  final bool googleDriveConnected;

  /// Connected Google Drive account email, if any.
  final String? googleDriveEmail;

  /// Timestamp of the last successful backup (ISO 8601 string).
  final String? lastBackupTime;

  static const Object _unchanged = Object();

  AppSettings copyWith({
    AppThemeMode? themeMode,
    Object? localeCode = _unchanged,
    ReadingDirection? readingDirection,
    bool? aiEnabled,
    String? aiProvider,
    Map<String, String>? aiModels,
    String? backupFrequency,
    bool? googleDriveConnected,
    Object? googleDriveEmail = _unchanged,
    Object? lastBackupTime = _unchanged,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      localeCode: identical(localeCode, _unchanged)
          ? this.localeCode
          : localeCode as String?,
      readingDirection: readingDirection ?? this.readingDirection,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiProvider: aiProvider ?? this.aiProvider,
      aiModels: aiModels ?? this.aiModels,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      googleDriveConnected:
          googleDriveConnected ?? this.googleDriveConnected,
      googleDriveEmail: identical(googleDriveEmail, _unchanged)
          ? this.googleDriveEmail
          : googleDriveEmail as String?,
      lastBackupTime: identical(lastBackupTime, _unchanged)
          ? this.lastBackupTime
          : lastBackupTime as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.themeMode == themeMode &&
          other.localeCode == localeCode &&
          other.readingDirection == readingDirection &&
          other.aiEnabled == aiEnabled &&
          other.aiProvider == aiProvider &&
          other.backupFrequency == backupFrequency &&
          other.googleDriveConnected == googleDriveConnected &&
          other.googleDriveEmail == googleDriveEmail &&
          other.lastBackupTime == lastBackupTime &&
          _sameModels(other.aiModels, aiModels);

  @override
  int get hashCode => Object.hash(
    themeMode,
    localeCode,
    readingDirection,
    aiEnabled,
    aiProvider,
    backupFrequency,
    googleDriveConnected,
    googleDriveEmail,
    lastBackupTime,
    Object.hashAllUnordered(
      aiModels.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  static bool _sameModels(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);
}
