import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/page_state_colors.dart';
import 'package:personaltskmng/domain/models/page_state.dart';

/// The state's letters (ND, D2, F3 ...) on the state's color. Letters are
/// domain terms and are never translated.
class StateBadge extends StatelessWidget {
  const StateBadge({super.key, required this.state, this.dense = false});

  final PageState state;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.pageStateColors;
    final style = Theme.of(context).textTheme.labelMedium;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 1 : 3,
      ),
      decoration: BoxDecoration(
        color: colors.of(state),
        borderRadius: BorderRadius.circular(AppRadius.chip - 4),
      ),
      child: Text(
        state.name.toUpperCase(),
        style: style?.copyWith(
          color: colors.onColorOf(state),
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}

/// Every page of the Q as one strip, in page order: the health of the whole
/// text at a glance, like the edge of a closed book. Runs of the same state
/// are drawn as one block, and a run is never thinner than one pixel, so a
/// single lapsed page stays visible.
class PageSpine extends StatelessWidget {
  const PageSpine({super.key, required this.states, this.height = 14});

  /// One entry per page, page 1 first.
  final List<PageState> states;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.pageStateColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip - 6),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SpinePainter(states, colors)),
      ),
    );
  }
}

class _SpinePainter extends CustomPainter {
  _SpinePainter(this.states, this.colors);

  final List<PageState> states;
  final PageStateColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.nd);
    if (states.isEmpty) return;
    final unit = size.width / states.length;
    final paint = Paint()..isAntiAlias = false;
    var runStart = 0;
    for (var i = 1; i <= states.length; i++) {
      if (i < states.length && states[i] == states[runStart]) continue;
      final state = states[runStart];
      if (state != PageState.nd) {
        final left = (runStart * unit).floorToDouble();
        var right = (i * unit).ceilToDouble();
        if (right <= left) right = left + 1;
        if (right > size.width) right = size.width;
        paint.color = colors.of(state);
        canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), paint);
      }
      runStart = i;
    }
  }

  @override
  bool shouldRepaint(_SpinePainter old) {
    if (old.colors != colors || old.states.length != states.length) return true;
    for (var i = 0; i < states.length; i++) {
      if (old.states[i] != states[i]) return true;
    }
    return false;
  }
}

/// How many pages are in each state, as one bar whose segments are
/// proportional to the counts. Ordered from most to least learned, with ND
/// last, so the bar reads left to right as "what is solid" to "not started".
class StateDistributionBar extends StatelessWidget {
  const StateDistributionBar({
    super.key,
    required this.counts,
    this.height = 14,
  });

  final Map<PageState, int> counts;
  final double height;

  static const List<PageState> order = [
    PageState.c,
    PageState.d3,
    PageState.d2,
    PageState.d1,
    PageState.f1,
    PageState.f2,
    PageState.f3,
    PageState.nd,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.pageStateColors;
    final segments = <Widget>[];
    for (final state in order) {
      final count = counts[state] ?? 0;
      if (count <= 0) continue;
      if (segments.isNotEmpty) segments.add(const SizedBox(width: 2));
      segments.add(
        Expanded(
          flex: count,
          child: ColoredBox(color: colors.of(state)),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: segments.isEmpty
            ? null
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: segments,
              ),
      ),
    );
  }
}
