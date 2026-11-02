import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/notes_slivers.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/position_nav.dart';

/// The layout of every unit screen (a p, an s, a ch, a juz, a part): the unit's
/// info and its navigation ("More details") together at the top, then the notes
/// block with its pinned header and "+", all in one scrolling area.
///
/// This is the INFO side only. The Quran is read on the reader (`ReaderPage`),
/// which the switch under the title opens. A juz has no notes of its own: with
/// [unit] null the screen has no notes block.
class UnitScreen extends StatelessWidget {
  const UnitScreen({
    super.key,
    required this.title,
    required this.info,
    this.unit,
    this.navigation,
    this.positionLabel,
    this.onPrevious,
    this.onNext,
    this.sideToggle,
  });

  final String title;

  /// The info block (a `PageInfoCard`, `ScopeInfoCard` or `JuzInfoCard`).
  final Widget info;

  /// "More details", only when the unit has more than one page.
  final Widget? navigation;

  /// Whose notes the screen shows; null: none (a juz).
  final NoteUnit? unit;

  /// Optional position among siblings (e.g. "12 / 604" or "ch 3 / 71").
  final String? positionLabel;

  /// Callback to navigate to the previous sibling.
  final VoidCallback? onPrevious;

  /// Callback to navigate to the next sibling.
  final VoidCallback? onNext;

  /// The Info | Quran switch under the title bar (null: none, as on the info
  /// screens the reader opens: Back returns to it).
  final Widget? sideToggle;

  /// The height of the slot of [sideToggle] under the title bar. The toggle
  /// scales down inside it when the text is big, so it never overflows.
  static const double _toggleHeight = 44;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final navigation = this.navigation;
    final positionLabel = this.positionLabel;
    final onPrevious = this.onPrevious;
    final onNext = this.onNext;
    final sideToggle = this.sideToggle;

    return Scaffold(
      appBar: AppBar(
        bottom: sideToggle == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(_toggleHeight),
                child: SizedBox(height: _toggleHeight, child: sideToggle),
              ),
        title: Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: AppTheme.serif,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (positionLabel != null || onPrevious != null || onNext != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: PositionNav(
                positionLabel: positionLabel,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formMaxWidth,
          ),
          child: _InfoAndNotes(
            info: info,
            navigation: navigation,
            unit: unit,
          ),
        ),
      ),
    );
  }
}

/// The info side of a unit screen: the info and its navigation together at the
/// top, then the notes, in one scrolling area.
class _InfoAndNotes extends StatelessWidget {
  const _InfoAndNotes({
    required this.info,
    required this.navigation,
    required this.unit,
  });

  final Widget info;
  final Widget? navigation;
  final NoteUnit? unit;

  @override
  Widget build(BuildContext context) {
    final navigation = this.navigation;
    final unit = this.unit;
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 360
            ? AppSpacing.md
            : AppSpacing.lg;
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.lg,
                horizontalPadding,
                AppSpacing.md,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    if (navigation != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      navigation,
                    ],
                  ],
                ),
              ),
            ),
            if (unit != null) NotesSlivers(unit: unit),
          ],
        );
      },
    );
  }
}
