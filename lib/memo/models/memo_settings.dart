import 'package:personaltskmng/memo/models/status_rules.dart';

/// The few things the user decides. Everything here can change at any time: the
/// statuses are worked out again from the log, nothing is ever stale.
final class MemoSettings {
  const MemoSettings({
    this.rules = StatusRules.defaults,
    this.sensible = true,
    this.partitionId = defaultPartitionId,
    this.attentionDays = defaultAttentionDays,
    this.attentionLimit = defaultAttentionLimit,
    this.trackReading = true,
    this.readMinSeconds = defaultReadMinSeconds,
    this.readMemoriseSeconds = defaultReadMemoriseSeconds,
    this.readIdleSeconds = defaultReadIdleSeconds,
    this.readKeepDays = defaultReadKeepDays,
  });

  /// The partition the overview and the planner open with: the user's own ch.
  static const String defaultPartitionId = 'ch';

  /// Today's "needs attention" list shows the pieces where something falls a
  /// step within this many days (and every piece that is already fading or
  /// forgotten).
  static const int defaultAttentionDays = 3;

  /// The most pieces Today's "needs attention" list shows.
  static const int defaultAttentionLimit = 12;

  /// Days the reading evidence is kept before it is dropped.
  static const int defaultReadKeepDays = 30;

  /// Reading suggestions (see `ReadingDraft`): a page the reader showed for less
  /// than this many seconds in a day is not counted as read.
  static const int defaultReadMinSeconds = 90;

  /// On a page with nothing learned, this many seconds in a day make the
  /// suggestion Memorise instead of nothing (just reading is not memorising).
  static const int defaultReadMemoriseSeconds = 300;

  /// Time on a page stops counting this many seconds after the last touch,
  /// because a phone left open on a page is not reading. Generous on purpose:
  /// reciting while looking at a page does not touch the screen.
  static const int defaultReadIdleSeconds = 600;

  /// The numbers behind the statuses (see [StatusRules]).
  final StatusRules rules;

  /// When true, Memorise is only taken on ayahs that are not learned (or are
  /// forgotten) and Review only on ayahs that are learned: the part of a logged
  /// range that does not fit is left out and the user is told. When false,
  /// anything is recorded as typed.
  final bool sensible;

  /// The id of the partition shown by default.
  final String partitionId;

  /// How many days ahead Today looks for what is about to fall.
  final int attentionDays;

  /// The most pieces the "needs attention" list shows.
  final int attentionLimit;

  /// Whether the reader keeps the time spent on each page, to suggest a log.
  final bool trackReading;
  final int readMinSeconds;
  final int readMemoriseSeconds;
  final int readIdleSeconds;

  /// How many days of reading evidence are kept.
  final int readKeepDays;

  /// Why these settings cannot be used, or null when they can.
  String? get problem =>
      rules.problem ??
      (attentionDays < 1 || attentionDays > 60 ? 'attention' : null) ??
      (attentionLimit < 1 || attentionLimit > 100 ? 'attentionLimit' : null) ??
      (readKeepDays < 1 || readKeepDays > 365 ? 'readKeep' : null) ??
      (readMinSeconds < 5 || readMinSeconds > 3600 ? 'readMin' : null) ??
      (readMemoriseSeconds < readMinSeconds || readMemoriseSeconds > 36000
          ? 'readMemorise'
          : null) ??
      (readIdleSeconds < 30 || readIdleSeconds > 7200 ? 'readIdle' : null);

  MemoSettings copyWith({
    StatusRules? rules,
    bool? sensible,
    String? partitionId,
    int? attentionDays,
    int? attentionLimit,
    bool? trackReading,
    int? readMinSeconds,
    int? readMemoriseSeconds,
    int? readIdleSeconds,
    int? readKeepDays,
  }) => MemoSettings(
    rules: rules ?? this.rules,
    sensible: sensible ?? this.sensible,
    partitionId: partitionId ?? this.partitionId,
    attentionDays: attentionDays ?? this.attentionDays,
    attentionLimit: attentionLimit ?? this.attentionLimit,
    trackReading: trackReading ?? this.trackReading,
    readMinSeconds: readMinSeconds ?? this.readMinSeconds,
    readMemoriseSeconds: readMemoriseSeconds ?? this.readMemoriseSeconds,
    readIdleSeconds: readIdleSeconds ?? this.readIdleSeconds,
    readKeepDays: readKeepDays ?? this.readKeepDays,
  );

  Map<String, Object?> toJson() => {
    'rules': rules.toJson(),
    'sensible': sensible,
    'partition': partitionId,
    'attention': attentionDays,
    'attentionLimit': attentionLimit,
    'trackReading': trackReading,
    'readMin': readMinSeconds,
    'readMemorise': readMemoriseSeconds,
    'readIdle': readIdleSeconds,
    'readKeep': readKeepDays,
  };

  /// Reads what [toJson] wrote; anything missing or unusable falls back to the
  /// default for that one field.
  static MemoSettings fromJson(Object? json) {
    if (json is! Map) return const MemoSettings();
    final sensible = json['sensible'];
    final partition = json['partition'];
    final attention = json['attention'];
    final track = json['trackReading'];
    final readMin = json['readMin'];
    final readMemorise = json['readMemorise'];
    final readIdle = json['readIdle'];
    final limit = json['attentionLimit'];
    final keep = json['readKeep'];
    final candidate = MemoSettings(
      rules: StatusRules.fromJson(json['rules']),
      sensible: sensible is bool ? sensible : true,
      partitionId: partition is String && partition.isNotEmpty
          ? partition
          : defaultPartitionId,
      attentionDays: attention is int && attention >= 1 && attention <= 60
          ? attention
          : defaultAttentionDays,
      attentionLimit: limit is int ? limit : defaultAttentionLimit,
      readKeepDays: keep is int ? keep : defaultReadKeepDays,
      trackReading: track is bool ? track : true,
      readMinSeconds: readMin is int ? readMin : defaultReadMinSeconds,
      readMemoriseSeconds: readMemorise is int
          ? readMemorise
          : defaultReadMemoriseSeconds,
      readIdleSeconds: readIdle is int ? readIdle : defaultReadIdleSeconds,
    );
    if (candidate.problem == null) return candidate;
    // Something does not hold together: the reading numbers fall back, the rest
    // stays.
    return candidate.copyWith(
      attentionDays: attention is int && attention >= 1 && attention <= 60
          ? attention
          : defaultAttentionDays,
      attentionLimit: defaultAttentionLimit,
      readKeepDays: defaultReadKeepDays,
      readMinSeconds: defaultReadMinSeconds,
      readMemoriseSeconds: defaultReadMemoriseSeconds,
      readIdleSeconds: defaultReadIdleSeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MemoSettings &&
      other.rules == rules &&
      other.sensible == sensible &&
      other.partitionId == partitionId &&
      other.attentionDays == attentionDays &&
      other.attentionLimit == attentionLimit &&
      other.readKeepDays == readKeepDays &&
      other.trackReading == trackReading &&
      other.readMinSeconds == readMinSeconds &&
      other.readMemoriseSeconds == readMemoriseSeconds &&
      other.readIdleSeconds == readIdleSeconds;

  @override
  int get hashCode => Object.hash(
    rules,
    sensible,
    partitionId,
    attentionDays,
    attentionLimit,
    readKeepDays,
    trackReading,
    readMinSeconds,
    readMemoriseSeconds,
    readIdleSeconds,
  );
}
