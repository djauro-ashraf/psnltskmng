import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/page_state_colors.dart';

/// Material 3 light + dark themes, hand-tuned.
///
/// The look: a well-set page. Spectral (a screen serif) carries titles and
/// the big numbers, IBM Plex Sans carries everything you tap or scan. The
/// surfaces are quiet neutrals and the primary is a deep mulberry, which is
/// far from every page-state hue, so the only saturated things on screen are
/// the page states themselves (see `PageStateColors`).
abstract final class AppTheme {
  /// Font families declared in pubspec.yaml.
  static const String serif = 'Spectral';
  static const String sans = 'IBMPlexSans';

  static const Color _seedColor = Color(0xFF6E3560);

  // Built once, lazily; not rebuilt on every access.
  static final ThemeData light = _build(Brightness.light);
  static final ThemeData dark = _build(Brightness.dark);

  // The roles Material would derive from the seed are overridden one by one:
  // the generated tonal-spot surfaces turn pink for a mulberry seed.
  static final ColorScheme _lightScheme =
      ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF6E3560),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFF1D9EA),
        onPrimaryContainer: const Color(0xFF3A0F31),
        secondary: const Color(0xFF5F5566),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFE7E1EA),
        onSecondaryContainer: const Color(0xFF231A29),
        tertiary: const Color(0xFF7A5900),
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFF6E6C8),
        onTertiaryContainer: const Color(0xFF3F2B00),
        surface: const Color(0xFFF8F7F9),
        onSurface: const Color(0xFF1D1B20),
        onSurfaceVariant: const Color(0xFF4A4650),
        surfaceContainerLowest: const Color(0xFFFFFFFF),
        surfaceContainerLow: const Color(0xFFF2F0F4),
        surfaceContainer: const Color(0xFFECE9EF),
        surfaceContainerHigh: const Color(0xFFE6E3EA),
        surfaceContainerHighest: const Color(0xFFE0DDE5),
        outline: const Color(0xFF7D7784),
        outlineVariant: const Color(0xFFD2CDD9),
        surfaceTint: Colors.transparent,
        inverseSurface: const Color(0xFF322F35),
        onInverseSurface: const Color(0xFFF5EFF7),
        inversePrimary: const Color(0xFFE6B5D8),
      );

  static final ColorScheme _darkScheme =
      ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFE6B5D8),
        onPrimary: const Color(0xFF4A1B40),
        primaryContainer: const Color(0xFF5B2B4E),
        onPrimaryContainer: const Color(0xFFFFD8F0),
        secondary: const Color(0xFFCEC3D3),
        onSecondary: const Color(0xFF342B39),
        secondaryContainer: const Color(0xFF4C4352),
        onSecondaryContainer: const Color(0xFFEBDFF0),
        tertiary: const Color(0xFFE6C26A),
        onTertiary: const Color(0xFF3F2E00),
        tertiaryContainer: const Color(0xFF4F3C0A),
        onTertiaryContainer: const Color(0xFFFCE3A3),
        surface: const Color(0xFF151317),
        onSurface: const Color(0xFFE7E1E8),
        onSurfaceVariant: const Color(0xFFCBC4CF),
        surfaceContainerLowest: const Color(0xFF100E12),
        surfaceContainerLow: const Color(0xFF1C1A1F),
        surfaceContainer: const Color(0xFF211F25),
        surfaceContainerHigh: const Color(0xFF2B292F),
        surfaceContainerHighest: const Color(0xFF36343A),
        outline: const Color(0xFF968F99),
        outlineVariant: const Color(0xFF4A454F),
        surfaceTint: Colors.transparent,
        inverseSurface: const Color(0xFFE7E1E8),
        onInverseSurface: const Color(0xFF322F35),
        inversePrimary: const Color(0xFF6E3560),
      );

  static TextTheme _textTheme(ColorScheme scheme) {
    // Every style starts as Plex Sans; the serif is applied on purpose to
    // titles and display numbers only.
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
    ).textTheme.apply(
      fontFamily: sans,
      displayColor: scheme.onSurface,
      bodyColor: scheme.onSurface,
    );

    TextStyle? serifOf(
      TextStyle? style, {
      required double size,
      required double height,
      double letterSpacing = 0,
    }) => style?.copyWith(
      fontFamily: serif,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w600,
      letterSpacing: letterSpacing,
    );

    return base.copyWith(
      // Big numbers: tabular so a changing minute count does not jitter.
      displaySmall: serifOf(
        base.displaySmall,
        size: 44,
        height: 1.05,
        letterSpacing: -0.5,
      )?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      headlineLarge: serifOf(
        base.headlineLarge,
        size: 32,
        height: 1.15,
        letterSpacing: -0.3,
      ),
      headlineMedium: serifOf(
        base.headlineMedium,
        size: 28,
        height: 1.2,
        letterSpacing: -0.2,
      ),
      headlineSmall: serifOf(base.headlineSmall, size: 24, height: 1.25),
      titleLarge: serifOf(base.titleLarge, size: 22, height: 1.25),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(height: 1.4),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark ? _darkScheme : _lightScheme;
    final text = _textTheme(scheme);

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );
    final panelShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      side: BorderSide(color: scheme.outlineVariant),
    );
    final heroShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.hero),
    );
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      extensions: <ThemeExtension<dynamic>>[
        isDark ? PageStateColors.dark : PageStateColors.light,
      ],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: panelShape,
      ),
      dialogTheme: DialogThemeData(
        shape: heroShape,
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.hero),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md + 2,
        ),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        disabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: controlShape,
          minimumSize: const Size(64, 48),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: controlShape,
          minimumSize: const Size(64, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: controlShape,
          minimumSize: const Size(64, 44),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        selectedColor: scheme.secondaryContainer,
        labelStyle: text.labelLarge,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll<OutlinedBorder>(controlShape),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : null,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurface,
          ),
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        // No hairlines above and below an open tile: the card is the frame.
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        linearMinHeight: 6,
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
          (states) => text.labelMedium?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: text.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: controlShape,
      ),
    );
  }
}
