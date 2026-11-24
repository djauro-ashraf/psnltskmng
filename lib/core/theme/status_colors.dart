import 'package:flutter/material.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';

/// The colors of the eight statuses, as a theme extension so every screen paints
/// a status the same way.
///
/// Meaning, not decoration: blue deepens as an ayah matures through the three
/// learning levels, green is consolidated, and the warm colors are ayahs that
/// slipped (fading 1 yellow, fading 2 orange, forgotten red). Not learned is a
/// neutral that stays out of the way. In the dark theme "more mature" reads as
/// brighter instead of darker, the same convention contribution graphs use, so
/// the ramp keeps its order.
///
/// A status must never rely on color alone: every use pairs the color with the
/// status's name.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.notLearned,
    required this.learning1,
    required this.learning2,
    required this.learning3,
    required this.consolidated,
    required this.fading1,
    required this.fading2,
    required this.forgotten,
  });

  static const StatusColors light = StatusColors(
    notLearned: Color(0xFFD5D0DA),
    learning1: Color(0xFFB9D1F4),
    learning2: Color(0xFF6EA0E6),
    learning3: Color(0xFF2D62B4),
    consolidated: Color(0xFF237A4E),
    fading1: Color(0xFFF4D35E),
    fading2: Color(0xFFF0A236),
    forgotten: Color(0xFFD4423A),
  );

  static const StatusColors dark = StatusColors(
    notLearned: Color(0xFF3F3A46),
    learning1: Color(0xFF35557F),
    learning2: Color(0xFF5E8FD6),
    learning3: Color(0xFF9BC2F8),
    consolidated: Color(0xFF5CC48F),
    fading1: Color(0xFFE8CA5A),
    fading2: Color(0xFFF2A648),
    forgotten: Color(0xFFF26D65),
  );

  final Color notLearned;
  final Color learning1;
  final Color learning2;
  final Color learning3;
  final Color consolidated;
  final Color fading1;
  final Color fading2;
  final Color forgotten;

  Color of(MemoStatus status) => switch (status) {
    MemoStatus.notLearned => notLearned,
    MemoStatus.learning1 => learning1,
    MemoStatus.learning2 => learning2,
    MemoStatus.learning3 => learning3,
    MemoStatus.consolidated => consolidated,
    MemoStatus.fading1 => fading1,
    MemoStatus.fading2 => fading2,
    MemoStatus.forgotten => forgotten,
  };

  /// Text or icon color that stays readable on top of [of] (status).
  Color onColorOf(MemoStatus status) => foregroundOn(of(status));

  /// White or near-black, whichever has more contrast on [fill].
  static Color foregroundOn(Color fill) {
    final l = fill.computeLuminance();
    final withWhite = 1.05 / (l + 0.05);
    final withInk = (l + 0.05) / 0.06;
    return withWhite >= withInk ? Colors.white : const Color(0xFF1B1B1F);
  }

  @override
  StatusColors copyWith({
    Color? notLearned,
    Color? learning1,
    Color? learning2,
    Color? learning3,
    Color? consolidated,
    Color? fading1,
    Color? fading2,
    Color? forgotten,
  }) => StatusColors(
    notLearned: notLearned ?? this.notLearned,
    learning1: learning1 ?? this.learning1,
    learning2: learning2 ?? this.learning2,
    learning3: learning3 ?? this.learning3,
    consolidated: consolidated ?? this.consolidated,
    fading1: fading1 ?? this.fading1,
    fading2: fading2 ?? this.fading2,
    forgotten: forgotten ?? this.forgotten,
  );

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      notLearned: Color.lerp(notLearned, other.notLearned, t)!,
      learning1: Color.lerp(learning1, other.learning1, t)!,
      learning2: Color.lerp(learning2, other.learning2, t)!,
      learning3: Color.lerp(learning3, other.learning3, t)!,
      consolidated: Color.lerp(consolidated, other.consolidated, t)!,
      fading1: Color.lerp(fading1, other.fading1, t)!,
      fading2: Color.lerp(fading2, other.fading2, t)!,
      forgotten: Color.lerp(forgotten, other.forgotten, t)!,
    );
  }
}

extension StatusColorsX on BuildContext {
  /// The status palette of the current theme.
  StatusColors get statusColors {
    final theme = Theme.of(this);
    return theme.extension<StatusColors>() ??
        (theme.brightness == Brightness.dark
            ? StatusColors.dark
            : StatusColors.light);
  }
}
