import 'package:flutter/material.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/status_colors.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/memo/models/memo_status.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/shared/widgets/status_sheet.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// The status's name on the status's color. Tapping it says what the status
/// means (see `showStatusSheet`), so a badge is never a mystery.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.dense = false});

  final MemoStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final style = Theme.of(context).textTheme.labelMedium;
    final radius = BorderRadius.circular(AppRadius.chip - 4);
    return Material(
      color: colors.of(status),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: radius,
        onTap: () => showStatusSheet(context, status),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 6 : 8,
            vertical: dense ? 1 : 3,
          ),
          child: Text(
            MemoText.of(context).status(status),
            style: style?.copyWith(
              color: colors.onColorOf(status),
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// A strip of cells, one per piece, in order: the health of the whole text at a
/// glance, like the edge of a closed book. Runs of the same status are drawn as
/// one block and a run is never thinner than one pixel, so a single forgotten
/// piece stays visible.
///
/// The strip runs the way the text runs (`context.textRunsRightToLeft`, from the
/// "Reading direction" setting): right to left puts the first piece at the right
/// edge.
class StatusSpine extends StatelessWidget {
  const StatusSpine({super.key, required this.statuses, this.height = 14});

  final List<MemoStatus> statuses;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.chip - 6),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SpinePainter(
            statuses,
            colors,
            rightToLeft: context.textRunsRightToLeft,
          ),
        ),
      ),
    );
  }
}

class _SpinePainter extends CustomPainter {
  _SpinePainter(this.statuses, this.colors, {required this.rightToLeft});

  final List<MemoStatus> statuses;
  final StatusColors colors;
  final bool rightToLeft;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.notLearned);
    if (statuses.isEmpty) return;
    if (rightToLeft) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final unit = size.width / statuses.length;
    final paint = Paint()..isAntiAlias = false;
    var runStart = 0;
    for (var i = 1; i <= statuses.length; i++) {
      if (i < statuses.length && statuses[i] == statuses[runStart]) continue;
      final status = statuses[runStart];
      if (status != MemoStatus.notLearned) {
        final left = (runStart * unit).floorToDouble();
        var right = (i * unit).ceilToDouble();
        if (right <= left) right = left + 1;
        if (right > size.width) right = size.width;
        paint.color = colors.of(status);
        canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), paint);
      }
      runStart = i;
    }
  }

  @override
  bool shouldRepaint(_SpinePainter old) {
    if (old.colors != colors ||
        old.rightToLeft != rightToLeft ||
        old.statuses.length != statuses.length) {
      return true;
    }
    for (var i = 0; i < statuses.length; i++) {
      if (old.statuses[i] != statuses[i]) return true;
    }
    return false;
  }
}

/// How many ayahs are in each status, as one bar whose segments are
/// proportional to the counts, in the order of the statuses.
class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.status, this.height = 10});

  final SpanStatus status;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = context.statusColors;
    final segments = <Widget>[];
    for (final s in MemoStatus.values) {
      final n = status.count(s);
      if (n <= 0) continue;
      if (segments.isNotEmpty) segments.add(const SizedBox(width: 2));
      segments.add(Expanded(flex: n, child: ColoredBox(color: colors.of(s))));
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
