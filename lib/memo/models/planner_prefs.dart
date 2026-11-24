/// What the user tells the AI planner: in their own words, what they want and
/// what comes first. There is a default text; the user can replace it.
final class PlannerPrefs {
  const PlannerPrefs({
    this.useDefault = true,
    this.text = '',
    this.minutes = defaultMinutes,
    this.maxItems = defaultMaxItems,
    this.recentDays = defaultRecentDays,
  });

  /// Minutes a day the user has, as a starting point.
  static const int defaultMinutes = 45;

  /// The most suggestions the planner is asked for.
  static const int defaultMaxItems = 8;

  /// How many days of your log the planner is shown.
  static const int defaultRecentDays = 10;

  /// The planner's default wishes.
  static const String defaultText =
      'First keep what I have memorised alive: review what is lapsed or most '
      'overdue before anything else. Then, if there is time left, suggest one '
      'small new M right next to what I already know. Keep the day short and '
      'realistic: a few pieces, never the whole Quran.';

  /// True: the planner uses [defaultText] and ignores [text].
  final bool useDefault;

  /// The user's own wishes (used when [useDefault] is false and it is not
  /// blank).
  final String text;

  final int minutes;
  final int maxItems;
  final int recentDays;

  /// The wishes the planner is actually told.
  String get effectiveText =>
      useDefault || text.trim().isEmpty ? defaultText : text.trim();

  PlannerPrefs copyWith({
    bool? useDefault,
    String? text,
    int? minutes,
    int? maxItems,
    int? recentDays,
  }) => PlannerPrefs(
    useDefault: useDefault ?? this.useDefault,
    text: text ?? this.text,
    minutes: minutes ?? this.minutes,
    maxItems: maxItems ?? this.maxItems,
    recentDays: recentDays ?? this.recentDays,
  );

  Map<String, Object?> toJson() => {
    'useDefault': useDefault,
    'text': text,
    'minutes': minutes,
    'maxItems': maxItems,
    'recentDays': recentDays,
  };

  static PlannerPrefs fromJson(Object? json) {
    if (json is! Map) return const PlannerPrefs();
    final use = json['useDefault'];
    final text = json['text'];
    final minutes = json['minutes'];
    final items = json['maxItems'];
    final recent = json['recentDays'];
    return PlannerPrefs(
      useDefault: use is bool ? use : true,
      text: text is String ? text : '',
      minutes: minutes is int && minutes >= 5 && minutes <= 1440
          ? minutes
          : defaultMinutes,
      maxItems: items is int && items >= 1 && items <= 30 ? items : defaultMaxItems,
      recentDays: recent is int && recent >= 1 && recent <= 60
          ? recent
          : defaultRecentDays,
    );
  }
}
