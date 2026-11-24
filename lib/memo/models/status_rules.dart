/// Ready-made sets of numbers, so the user can pick an intention instead of 43
/// numbers and then adjust.
enum RulesPreset {
  /// The original numbers.
  original,

  /// Fewer reviews to climb, more days before anything fades, more slack.
  relaxed,

  /// More reviews to climb, fewer days before anything fades, less slack.
  strict,
}

/// The numbers behind the statuses: how many reviews it takes to move up a
/// learning level, how long a gap is tolerated, and how many days without a
/// review it takes to start fading, step down or be forgotten. The defaults are
/// exactly the original numbers; every one of them can be changed by the user
/// and the statuses are worked out again from the log, so nothing is ever stale.
///
/// A "prime" ayah has been consolidated at least once: it needs fewer reviews
/// and gets more slack while learning. Pure Dart.
final class StatusRules {
  const StatusRules._(this._values);

  /// The original numbers.
  static const StatusRules defaults = StatusRules._(_defaults);

  static const Map<String, int> _defaults = {
    // Reviews (units) needed to leave learning level 1, 2, 3.
    'target.1': 7, 'target.2': 7, 'target.3': 14,
    'primeTarget.1': 4, 'primeTarget.2': 4, 'primeTarget.3': 7,
    // Largest gap in days since the last touch that still earns a unit.
    'gap.1': 1, 'gap.2': 1, 'gap.3': 2,
    'primeGap.1': 2, 'primeGap.2': 2, 'primeGap.3': 3,
    // Days beyond the tolerated gap that cost nothing, then the units lost.
    'forgive.1': 1, 'forgive.2': 2, 'forgive.3': 0,
    'penalty.1': 2, 'penalty.2': 1, 'penalty.3': 2,
    // Days without review: fading 1, fading 2, then one step down.
    'fade1.1': 1, 'fade2.1': 2, 'drop.1': 3,
    'fade1.2': 2, 'fade2.2': 3, 'drop.2': 4,
    'fade1.3': 3, 'fade2.3': 5, 'drop.3': 6,
    'primeFade1.1': 2, 'primeFade2.1': 3, 'primeDrop.1': 4,
    'primeFade1.2': 3, 'primeFade2.2': 4, 'primeDrop.2': 5,
    'primeFade1.3': 4, 'primeFade2.3': 7, 'primeDrop.3': 8,
    // Consolidated: days without review until fading 1, fading 2, forgotten.
    'c.fade1': 8, 'c.fade2': 14, 'c.forgotten': 18,
  };

  final Map<String, int> _values;

  /// The numbers of [preset]. Always consistent (see [problem]).
  static StatusRules ofPreset(RulesPreset preset) => switch (preset) {
    RulesPreset.original => defaults,
    RulesPreset.relaxed => _scaled(units: 0.7, days: 1.5, forgiveness: 1),
    RulesPreset.strict => _scaled(units: 1.3, days: 0.7, forgiveness: -1),
  };

  /// The preset these numbers are exactly, or null when they are the user's own.
  RulesPreset? get preset {
    for (final p in RulesPreset.values) {
      if (this == ofPreset(p)) return p;
    }
    return null;
  }

  /// The original numbers with the units (reviews) and the days multiplied, the
  /// forgiven days moved, and each ladder of days kept strictly increasing.
  static StatusRules _scaled({
    required double units,
    required double days,
    required int forgiveness,
  }) {
    final v = <String, int>{};
    for (final entry in _defaults.entries) {
      final key = entry.key;
      final base = entry.value;
      if (key.startsWith('target') || key.startsWith('primeTarget')) {
        v[key] = (base * units).round().clamp(2, 3650);
      } else if (key.startsWith('forgive')) {
        v[key] = (base + forgiveness).clamp(0, 3650);
      } else if (key.startsWith('penalty')) {
        v[key] = base;
      } else {
        v[key] = (base * days).round().clamp(1, 3650);
      }
    }
    void ladder(String a, String b, String c) {
      if (v[b]! <= v[a]!) v[b] = v[a]! + 1;
      if (v[c]! <= v[b]!) v[c] = v[b]! + 1;
    }

    for (var level = 1; level <= 3; level++) {
      ladder('fade1.$level', 'fade2.$level', 'drop.$level');
      ladder('primeFade1.$level', 'primeFade2.$level', 'primeDrop.$level');
    }
    ladder('c.fade1', 'c.fade2', 'c.forgotten');
    return StatusRules._(v);
  }

  /// Every key, in the order the settings list them.
  static List<String> get keys => _defaults.keys.toList();

  int value(String key) => _values[key] ?? _defaults[key]!;

  /// The same rules with [key] set to [value].
  StatusRules withValue(String key, int value) {
    if (!_defaults.containsKey(key)) return this;
    return StatusRules._({..._values, key: value});
  }

  /// The ladders of days: each must increase strictly (a warning, a stronger
  /// warning, then the fall).
  static const List<List<String>> _ladders = [
    ['fade1.1', 'fade2.1', 'drop.1'],
    ['fade1.2', 'fade2.2', 'drop.2'],
    ['fade1.3', 'fade2.3', 'drop.3'],
    ['primeFade1.1', 'primeFade2.1', 'primeDrop.1'],
    ['primeFade1.2', 'primeFade2.2', 'primeDrop.2'],
    ['primeFade1.3', 'primeFade2.3', 'primeDrop.3'],
    ['c.fade1', 'c.fade2', 'c.forgotten'],
  ];

  /// The same rules with [key] set to [value], and the rest of its ladder moved
  /// just enough to stay in order (a later step is pushed up, an earlier one is
  /// pulled down), so editing one number never leaves the rules unusable.
  /// Returns the keys that were moved besides [key] in [moved] when given.
  StatusRules adjusted(String key, int value, {Set<String>? moved}) {
    if (!_defaults.containsKey(key)) return this;
    final v = {..._values};
    v[key] = value;
    for (final ladder in _ladders) {
      final at = ladder.indexOf(key);
      if (at < 0) continue;
      // The first step is at least 1 day, the second 2, the third 3.
      if (v[key]! < at + 1) v[key] = at + 1;
      for (var i = at + 1; i < ladder.length; i++) {
        if (v[ladder[i]]! <= v[ladder[i - 1]]!) {
          v[ladder[i]] = v[ladder[i - 1]]! + 1;
          moved?.add(ladder[i]);
        }
      }
      for (var i = at - 1; i >= 0; i--) {
        if (v[ladder[i]]! >= v[ladder[i + 1]]!) {
          v[ladder[i]] = v[ladder[i + 1]]! - 1;
          moved?.add(ladder[i]);
        }
      }
    }
    return StatusRules._(v);
  }

  /// True when nothing differs from the original numbers.
  bool get isDefault {
    for (final key in _defaults.keys) {
      if (value(key) != _defaults[key]) return false;
    }
    return true;
  }

  // -- the numbers by level (1 to 3) --------------------------------------------
  int target(int level, {required bool prime}) =>
      value('${prime ? 'primeTarget' : 'target'}.$level');
  int toleratedGap(int level, {required bool prime}) =>
      value('${prime ? 'primeGap' : 'gap'}.$level');
  int forgiveness(int level) => value('forgive.$level');
  int penalty(int level) => value('penalty.$level');
  int fade1(int level, {required bool prime}) =>
      value('${prime ? 'primeFade1' : 'fade1'}.$level');
  int fade2(int level, {required bool prime}) =>
      value('${prime ? 'primeFade2' : 'fade2'}.$level');
  int drop(int level, {required bool prime}) =>
      value('${prime ? 'primeDrop' : 'drop'}.$level');
  int get consolidatedFade1 => value('c.fade1');
  int get consolidatedFade2 => value('c.fade2');
  int get consolidatedForgotten => value('c.forgotten');

  /// Why these numbers cannot be used, or null when they can. The key of the
  /// first offending group is returned so a screen can point at it.
  String? get problem {
    for (final key in _defaults.keys) {
      final v = value(key);
      final isUnits = key.startsWith('target') || key.startsWith('primeTarget');
      final isGap = key.startsWith('gap') || key.startsWith('primeGap');
      final min = (isUnits || isGap || key.startsWith('fade') ||
              key.startsWith('primeFade') || key.startsWith('drop') ||
              key.startsWith('primeDrop') || key.startsWith('c.'))
          ? 1
          : 0;
      if (v < min || v > 3650) return key;
    }
    for (var level = 1; level <= 3; level++) {
      for (final prime in [false, true]) {
        if (!(fade1(level, prime: prime) < fade2(level, prime: prime) &&
            fade2(level, prime: prime) < drop(level, prime: prime))) {
          return '${prime ? 'primeFade1' : 'fade1'}.$level';
        }
      }
    }
    if (!(consolidatedFade1 < consolidatedFade2 &&
        consolidatedFade2 < consolidatedForgotten)) {
      return 'c.fade1';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
    for (final key in _defaults.keys)
      if (value(key) != _defaults[key]) key: value(key),
  };

  /// Reads what [toJson] wrote. Unknown keys and non-numbers are ignored; a
  /// result that does not hold together falls back to the original numbers.
  static StatusRules fromJson(Object? json) {
    if (json is! Map) return defaults;
    final values = {..._defaults};
    for (final key in _defaults.keys) {
      final v = json[key];
      if (v is int) values[key] = v;
    }
    final rules = StatusRules._(values);
    return rules.problem == null ? rules : defaults;
  }

  @override
  bool operator ==(Object other) {
    if (other is! StatusRules) return false;
    for (final key in _defaults.keys) {
      if (value(key) != other.value(key)) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hashAll([for (final key in _defaults.keys) value(key)]);
}
