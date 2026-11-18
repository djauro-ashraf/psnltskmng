import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// A swipe sideways over [child] that asks for the next or the previous unit:
/// the same step as the arrows of the reading line, for the screens too narrow
/// to show them (and for a thumb that would rather not reach up).
///
/// The way it points is the way the text runs, as in the Mushaf pager: with the
/// text running right to left (the default) a swipe to the right turns to the
/// next unit, as a page of a book is turned; running left to right it is a swipe
/// to the left. The arrows are laid out the same way.
///
/// It only listens to the raw touches (a `Listener`), it does not enter the
/// gesture arena: the scrolling under it, the taps on the cards and the long
/// presses are never held back or lost. A touch is a swipe when it ends mostly
/// sideways, far enough, and still moving at the end (see [UnitSwipe.read]); a
/// vertical scroll, a slow drag and a touch with two fingers are none.
class UnitSwipe extends StatefulWidget {
  const UnitSwipe({
    super.key,
    required this.onStep,
    required this.child,
    this.enabled = true,
  });

  /// Called with true for the next unit, false for the previous one.
  final ValueChanged<bool> onStep;

  /// False where a step has no meaning (the Whole Quran is one unit): touches
  /// are then not looked at.
  final bool enabled;

  final Widget child;

  /// The least a touch has to move sideways, in logical pixels.
  static const double minDistance = 56;

  /// The least speed along the way, at the moment the finger leaves the screen,
  /// in logical pixels per second.
  static const double minSpeed = 200;

  /// How much more sideways than up or down a swipe has to be (2: it may leave
  /// the horizontal by about 26 degrees).
  static const double sidewaysOver = 2;

  /// What a finished touch means: true for the next unit, false for the previous
  /// one, null for no swipe.
  ///
  /// [moved] is the way from where the finger went down to where it went up,
  /// [speed] its horizontal speed when it went up (the sign says the way: plus
  /// is toward the right), [rtl] whether the text runs right to left.
  ///
  /// Pure: the touch is measured by the widget, the meaning is decided here.
  static bool? read({
    required Offset moved,
    required double speed,
    required bool rtl,
  }) {
    final across = moved.dx.abs();
    if (across < minDistance) return null;
    if (across < moved.dy.abs() * sidewaysOver) return null;
    // Still moving, and still the same way: a finger that went one way and came
    // back, or that stopped before it lifted, is not a swipe.
    if (speed.abs() < minSpeed || speed.sign != moved.dx.sign) return null;
    final toTheRight = moved.dx > 0;
    return rtl ? toTheRight : !toTheRight;
  }

  @override
  State<UnitSwipe> createState() => _UnitSwipeState();
}

class _UnitSwipeState extends State<UnitSwipe> {
  /// The fingers that are down now (a second one cancels the touch).
  final Set<int> _fingers = <int>{};

  /// The finger that is followed; null when none is (nothing started, a second
  /// finger came, or the touch ended).
  int? _followed;
  Offset _from = Offset.zero;
  VelocityTracker? _velocity;

  void _onDown(PointerDownEvent event) {
    _fingers.add(event.pointer);
    if (_fingers.length == 1 && widget.enabled) {
      _followed = event.pointer;
      _from = event.position;
      _velocity = VelocityTracker.withKind(event.kind)
        ..addPosition(event.timeStamp, event.position);
    } else {
      _forget();
    }
  }

  void _onMove(PointerMoveEvent event) {
    if (event.pointer != _followed) return;
    _velocity?.addPosition(event.timeStamp, event.position);
  }

  void _onUp(PointerUpEvent event) {
    _fingers.remove(event.pointer);
    if (event.pointer != _followed) return;
    final velocity = _velocity;
    final moved = event.position - _from;
    _forget();
    if (velocity == null || !widget.enabled) return;
    final step = UnitSwipe.read(
      moved: moved,
      speed: velocity.getVelocity().pixelsPerSecond.dx,
      rtl: context.textRunsRightToLeft,
    );
    if (step != null) widget.onStep(step);
  }

  void _onCancel(PointerCancelEvent event) {
    _fingers.remove(event.pointer);
    if (event.pointer == _followed) _forget();
  }

  void _forget() {
    _followed = null;
    _velocity = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      // Also over the room between the cards, where the child has nothing to
      // hit.
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: widget.child,
    );
  }
}
