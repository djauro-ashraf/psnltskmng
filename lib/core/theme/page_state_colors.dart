import 'package:flutter/material.dart';
import 'package:personaltskmng/domain/models/page_state.dart';

/// The colors of the page states (ND, D1-D3, C, F1-F3), as a theme extension
/// so every screen paints a state the same way.
///
/// Meaning, not decoration: blue deepens as a page matures through D1-D3,
/// green is C (consolidated), and the warm colors are pages that slipped
/// (F1 yellow, F2 orange, F3 red). ND is a neutral that stays out of the way.
/// In the dark theme "more mature" reads as brighter instead of darker, the
/// same convention contribution graphs use, so the ramp keeps its order.
///
/// A state must never rely on color alone: every use pairs the color with the
/// state's letters (a StateBadge) or with a shape (the dot on F cells).
@immutable
class PageStateColors extends ThemeExtension<PageStateColors> {
  const PageStateColors({
    required this.nd,
    required this.d1,
    required this.d2,
    required this.d3,
    required this.c,
    required this.f1,
    required this.f2,
    required this.f3,
  });

  static const PageStateColors light = PageStateColors(
    nd: Color(0xFFD5D0DA),
    d1: Color(0xFFB9D1F4),
    d2: Color(0xFF6EA0E6),
    d3: Color(0xFF2D62B4),
    c: Color(0xFF237A4E),
    f1: Color(0xFFF4D35E),
    f2: Color(0xFFF0A236),
    f3: Color(0xFFD4423A),
  );

  static const PageStateColors dark = PageStateColors(
    nd: Color(0xFF3F3A46),
    d1: Color(0xFF35557F),
    d2: Color(0xFF5E8FD6),
    d3: Color(0xFF9BC2F8),
    c: Color(0xFF5CC48F),
    f1: Color(0xFFE8CA5A),
    f2: Color(0xFFF2A648),
    f3: Color(0xFFF26D65),
  );

  final Color nd;
  final Color d1;
  final Color d2;
  final Color d3;
  final Color c;
  final Color f1;
  final Color f2;
  final Color f3;

  Color of(PageState state) => switch (state) {
    PageState.nd => nd,
    PageState.d1 => d1,
    PageState.d2 => d2,
    PageState.d3 => d3,
    PageState.c => c,
    PageState.f1 => f1,
    PageState.f2 => f2,
    PageState.f3 => f3,
  };

  /// Text or icon color that stays readable on top of [of] (state).
  Color onColorOf(PageState state) => foregroundOn(of(state));

  /// White or near-black, whichever has more contrast on [fill].
  static Color foregroundOn(Color fill) {
    final l = fill.computeLuminance();
    final withWhite = 1.05 / (l + 0.05);
    final withInk = (l + 0.05) / 0.06;
    return withWhite >= withInk ? Colors.white : const Color(0xFF1B1B1F);
  }

  @override
  PageStateColors copyWith({
    Color? nd,
    Color? d1,
    Color? d2,
    Color? d3,
    Color? c,
    Color? f1,
    Color? f2,
    Color? f3,
  }) {
    return PageStateColors(
      nd: nd ?? this.nd,
      d1: d1 ?? this.d1,
      d2: d2 ?? this.d2,
      d3: d3 ?? this.d3,
      c: c ?? this.c,
      f1: f1 ?? this.f1,
      f2: f2 ?? this.f2,
      f3: f3 ?? this.f3,
    );
  }

  @override
  PageStateColors lerp(ThemeExtension<PageStateColors>? other, double t) {
    if (other is! PageStateColors) return this;
    return PageStateColors(
      nd: Color.lerp(nd, other.nd, t)!,
      d1: Color.lerp(d1, other.d1, t)!,
      d2: Color.lerp(d2, other.d2, t)!,
      d3: Color.lerp(d3, other.d3, t)!,
      c: Color.lerp(c, other.c, t)!,
      f1: Color.lerp(f1, other.f1, t)!,
      f2: Color.lerp(f2, other.f2, t)!,
      f3: Color.lerp(f3, other.f3, t)!,
    );
  }
}

extension PageStateColorsX on BuildContext {
  /// The state palette of the current theme.
  PageStateColors get pageStateColors {
    final theme = Theme.of(this);
    return theme.extension<PageStateColors>() ??
        (theme.brightness == Brightness.dark
            ? PageStateColors.dark
            : PageStateColors.light);
  }
}
