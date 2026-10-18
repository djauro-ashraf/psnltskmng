import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:personaltskmng/planning/data/planning_settings.dart';
import 'package:personaltskmng/planning/data/settings_codec.dart';

/// The planning settings being edited, kept in the JSON form of
/// `SettingsCodec` and not as built objects: a value such as a target of -3
/// cannot be built into `PlannerConstraints` (it asserts), but it can be typed,
/// shown with its message and fixed. Every change re-runs the same check the
/// controller runs on save (`settingsJsonProblems`), and the messages are kept
/// by field path (`constraints.expansionTargetPages`,
/// `time.sharedPageShare[106]`, ...).
class PlanningDraft extends ChangeNotifier {
  PlanningDraft(PlanningSettings saved) {
    _load(saved);
  }

  static final Map<String, Object?> _defaults = SettingsCodec.toJson(
    const PlanningSettings(),
  );

  late Map<String, Object?> _json;
  late String _savedText;
  Map<String, String> _errors = const {};
  List<SettingsProblem> _problems = const [];

  void _load(PlanningSettings saved) {
    _json = _copy(SettingsCodec.toJson(saved));
    _savedText = jsonEncode(_json);
    _validate();
  }

  static Map<String, Object?> _copy(Map<String, Object?> source) =>
      Map<String, Object?>.from(jsonDecode(jsonEncode(source)) as Map);

  void _validate() {
    _problems = settingsJsonProblems(_json);
    final byField = <String, List<String>>{};
    for (final p in _problems) {
      byField.putIfAbsent(p.field, () => []).add(p.message);
    }
    _errors = {for (final e in byField.entries) e.key: e.value.join('\n')};
  }

  /// Every problem, in order.
  List<SettingsProblem> get problems => _problems;

  /// The message of the field at [path], or null.
  String? errorOf(String path) => _errors[path];

  bool get valid => _problems.isEmpty;

  bool get dirty => jsonEncode(_json) != _savedText;

  /// The settings of the draft. Only meaningful when [valid].
  PlanningSettings build() => SettingsCodec.fromJson(_json).settings;

  /// Called after a successful save: the draft is now the saved state.
  void markSaved(PlanningSettings saved) {
    _load(saved);
    notifyListeners();
  }

  /// The value at [path] (`group.key` or `key`).
  Object? get(String path) {
    final dot = path.indexOf('.');
    if (dot < 0) return _json[path];
    final group = _json[path.substring(0, dot)];
    return group is Map ? group[path.substring(dot + 1)] : null;
  }

  void set(String path, Object? value) {
    final dot = path.indexOf('.');
    if (dot < 0) {
      _json[path] = value;
    } else {
      final key = path.substring(0, dot);
      final group = _json[key];
      if (group is Map) {
        group[path.substring(dot + 1)] = value;
      } else {
        _json[key] = {path.substring(dot + 1): value};
      }
    }
    _validate();
    notifyListeners();
  }

  /// Puts the default of every path in [paths] back.
  void resetPaths(Iterable<String> paths) {
    for (final path in paths) {
      final dot = path.indexOf('.');
      final fallback = dot < 0
          ? _defaults[path]
          : (_defaults[path.substring(0, dot)]! as Map)[path.substring(dot + 1)];
      final value = fallback is Map || fallback is List
          ? jsonDecode(jsonEncode(fallback))
          : fallback;
      final dot2 = path.indexOf('.');
      if (dot2 < 0) {
        _json[path] = value;
      } else {
        (_json[path.substring(0, dot2)]! as Map)[path.substring(dot2 + 1)] =
            value;
      }
    }
    _validate();
    notifyListeners();
  }

  void resetAll() {
    _json = _copy(_defaults);
    _validate();
    notifyListeners();
  }

  // ---- shared pages (time.sharedPageShare) ----

  Map<String, Object?> get _shares {
    final time = _json['time'];
    final shares = time is Map ? time['sharedPageShare'] : null;
    return shares is Map ? Map<String, Object?>.from(shares) : {};
  }

  /// The raw share stored for [page] (the earlier ch's share), or null when
  /// the page has no entry (0.5 is used).
  Object? shareOf(int page) => _shares['$page'];

  void setShare(int page, Object? value) {
    final shares = _shares;
    if (value == null) {
      shares.remove('$page');
    } else {
      shares['$page'] = value;
    }
    set('time.sharedPageShare', shares);
  }

  int get customShareCount => _shares.length;
}
