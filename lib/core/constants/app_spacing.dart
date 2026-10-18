abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Corner radii. Bigger surfaces get bigger corners, so the radius says
/// something about hierarchy instead of being one value everywhere.
abstract final class AppRadius {
  /// Kept for existing callers: the general rounded surface.
  static const double card = 20;

  /// Buttons, text fields, small tiles.
  static const double control = 12;

  /// Chips and badges.
  static const double chip = 10;

  /// Grouped lists and outlined panels.
  static const double panel = 20;

  /// The one big surface of a screen (today's summary), dialogs, sheets.
  static const double hero = 28;

  /// One page in the overview grid.
  static const double cell = 3;
}
