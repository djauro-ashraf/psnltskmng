abstract final class AppBreakpoints {
  /// Below this width: bottom navigation bar. At or above: navigation rail.
  static const double compact = 600;
  static const double medium = 900;

  /// At or above this width the navigation rail shows its labels beside icons.
  static const double expanded = 1200;

  /// Widest area used by page content on large screens.
  static const double contentMaxWidth = 1200;

  /// Widest area used by form-like pages (settings, details).
  static const double formMaxWidth = 640;

  /// Maximum width of centered empty / error states.
  static const double stateMaxWidth = 420;
}
