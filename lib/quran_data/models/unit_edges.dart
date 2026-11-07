import 'dart:convert';

import 'package:personaltskmng/quran_data/models/words_stream.dart';

/// What happens when the reader reaches the end (or start) of a reading unit.
enum UnitEdge {
  /// The next unit is simply more rows below/above without interruption.
  flow,

  /// The list stops with a visible tile. Pulling again (or pressing button) passes.
  gate,

  /// The list stops with a tile. Only buttons, arrows or swipe go to next unit.
  locked,
}

/// Settings for unit boundaries: global or per-unit.
final class UnitEdges {
  const UnitEdges({
    this.shared = true,
    this.all = UnitEdge.flow,
    this.byUnit = const {},
  });

  /// "Same for every unit": when true, [all] applies to all units.
  final bool shared;

  /// Used for all units when [shared] is true.
  final UnitEdge all;

  /// Per-unit choice when [shared] is false.
  final Map<WordsUnit, UnitEdge> byUnit;

  /// The active mode for [unit]. Quran unit is always [UnitEdge.flow].
  UnitEdge modeFor(WordsUnit unit) {
    if (unit == WordsUnit.quran) return UnitEdge.flow;
    if (shared) return all;
    return byUnit[unit] ?? all;
  }

  UnitEdges withShared(bool newShared) => UnitEdges(
        shared: newShared,
        all: all,
        byUnit: byUnit,
      );

  UnitEdges withAll(UnitEdge newAll) => UnitEdges(
        shared: shared,
        all: newAll,
        byUnit: byUnit,
      );

  UnitEdges withUnit(WordsUnit unit, UnitEdge mode) {
    final updated = Map<WordsUnit, UnitEdge>.from(byUnit);
    updated[unit] = mode;
    return UnitEdges(
      shared: shared,
      all: all,
      byUnit: updated,
    );
  }

  String encode() {
    return jsonEncode({
      'shared': shared,
      'all': all.name,
      'byUnit': byUnit.map((k, v) => MapEntry(k.name, v.name)),
    });
  }

  static UnitEdges decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const UnitEdges();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final shared = map['shared'] as bool? ?? true;
      final allName = map['all'] as String?;
      final all = UnitEdge.values.asNameMap()[allName] ?? UnitEdge.flow;
      final rawByUnit = map['byUnit'] as Map<String, dynamic>? ?? {};
      final byUnit = <WordsUnit, UnitEdge>{};
      for (final entry in rawByUnit.entries) {
        final u = WordsUnit.values.asNameMap()[entry.key];
        final m = UnitEdge.values.asNameMap()[entry.value as String];
        if (u != null && m != null) {
          byUnit[u] = m;
        }
      }
      return UnitEdges(
        shared: shared,
        all: all,
        byUnit: byUnit,
      );
    } catch (_) {
      return const UnitEdges();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitEdges &&
          other.shared == shared &&
          other.all == all &&
          other.byUnit.length == byUnit.length &&
          byUnit.entries.every((e) => other.byUnit[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
        shared,
        all,
        Object.hashAll(byUnit.entries.map((e) => Object.hash(e.key, e.value))),
      );
}

