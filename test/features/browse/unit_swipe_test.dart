import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/unit_swipe.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// The swipe that steps to the next or the previous unit of the words.
///
/// NOT RUN: written without being able to run Flutter.

/// A list under a [UnitSwipe] that records the steps (true: next) and the taps
/// on its rows, to show the swipe leaves the list its scrolling and its taps.
Widget _host({
  required List<bool> steps,
  List<int>? taps,
  bool enabled = true,
  TextDirection? flow,
}) {
  Widget body = UnitSwipe(
    enabled: enabled,
    onStep: steps.add,
    child: ListView(
      children: [
        for (var i = 0; i < 40; i++)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => taps?.add(i),
            child: SizedBox(height: 100, child: Center(child: Text('row $i'))),
          ),
      ],
    ),
  );
  if (flow != null) body = TextFlow(direction: flow, child: body);
  return MaterialApp(home: Scaffold(body: body));
}

double _scrolled(WidgetTester tester) =>
    tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

/// A quick swipe: [by] in the time [speed] (pixels per second) says.
Future<void> _swipe(WidgetTester tester, Offset by, {double speed = 1000}) =>
    tester.fling(find.byType(ListView), by, speed);

void main() {
  group('read: what a finished touch means', () {
    test('with the text running right to left, to the right is next', () {
      expect(
        UnitSwipe.read(moved: const Offset(120, 0), speed: 800, rtl: true),
        isTrue,
      );
      expect(
        UnitSwipe.read(moved: const Offset(-120, 0), speed: -800, rtl: true),
        isFalse,
      );
    });

    test('with the text running left to right, to the left is next', () {
      expect(
        UnitSwipe.read(moved: const Offset(-120, 0), speed: -800, rtl: false),
        isTrue,
      );
      expect(
        UnitSwipe.read(moved: const Offset(120, 0), speed: 800, rtl: false),
        isFalse,
      );
    });

    test('a touch that did not go far is not a swipe', () {
      const less = UnitSwipe.minDistance - 1;
      expect(
        UnitSwipe.read(moved: const Offset(less, 0), speed: 900, rtl: true),
        isNull,
      );
      expect(
        UnitSwipe.read(
          moved: const Offset(UnitSwipe.minDistance, 0),
          speed: 900,
          rtl: true,
        ),
        isTrue,
      );
    });

    test('a touch that was not moving when it ended is not a swipe', () {
      expect(
        UnitSwipe.read(moved: const Offset(200, 0), speed: 0, rtl: true),
        isNull,
      );
      expect(
        UnitSwipe.read(
          moved: const Offset(200, 0),
          speed: UnitSwipe.minSpeed - 1,
          rtl: true,
        ),
        isNull,
      );
      expect(
        UnitSwipe.read(
          moved: const Offset(200, 0),
          speed: UnitSwipe.minSpeed,
          rtl: true,
        ),
        isTrue,
      );
    });

    test('a touch that went one way and came back is not a swipe', () {
      expect(
        UnitSwipe.read(moved: const Offset(150, 0), speed: -900, rtl: true),
        isNull,
      );
      expect(
        UnitSwipe.read(moved: const Offset(-150, 0), speed: 900, rtl: true),
        isNull,
      );
    });

    test('a touch that went mostly up or down is not a swipe', () {
      // A scroll, with a little sideways in it.
      expect(
        UnitSwipe.read(moved: const Offset(80, 400), speed: 900, rtl: true),
        isNull,
      );
      expect(
        UnitSwipe.read(moved: const Offset(100, 60), speed: 900, rtl: true),
        isNull,
      );
      // At the limit (twice as far across as up) it still is one.
      expect(
        UnitSwipe.read(moved: const Offset(100, 50), speed: 900, rtl: true),
        isTrue,
      );
      expect(
        UnitSwipe.read(moved: const Offset(100, -50), speed: 900, rtl: true),
        isTrue,
      );
    });
  });

  group('over the words', () {
    testWidgets('a swipe to the right is next, to the left is back (right to left)', (
      tester,
    ) async {
      final steps = <bool>[];
      await tester.pumpWidget(_host(steps: steps));

      await _swipe(tester, const Offset(160, 0));
      expect(steps, [true]);
      await _swipe(tester, const Offset(-160, 0));
      expect(steps, [true, false]);
    });

    testWidgets('the other way round when the text runs left to right', (
      tester,
    ) async {
      final steps = <bool>[];
      await tester.pumpWidget(_host(steps: steps, flow: TextDirection.ltr));

      await _swipe(tester, const Offset(-160, 0));
      expect(steps, [true]);
      await _swipe(tester, const Offset(160, 0));
      expect(steps, [true, false]);
    });

    testWidgets('the way follows the setting when it changes', (tester) async {
      final steps = <bool>[];
      await tester.pumpWidget(_host(steps: steps, flow: TextDirection.rtl));
      await _swipe(tester, const Offset(160, 0));
      expect(steps, [true]);

      await tester.pumpWidget(_host(steps: steps, flow: TextDirection.ltr));
      await _swipe(tester, const Offset(160, 0));
      expect(steps, [true, false]);
    });

    testWidgets('a short swipe, a slow drag and a drag that stops are none', (
      tester,
    ) async {
      final steps = <bool>[];
      await tester.pumpWidget(_host(steps: steps));

      await _swipe(tester, const Offset(30, 0));
      // `drag` moves with no time to it: no speed.
      await tester.drag(find.byType(ListView), const Offset(160, 0));
      await tester.pump();
      expect(steps, isEmpty);
    });

    testWidgets('a scroll is not a swipe, and still scrolls', (tester) async {
      final steps = <bool>[];
      await tester.pumpWidget(_host(steps: steps));
      expect(_scrolled(tester), 0);

      await _swipe(tester, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(_scrolled(tester), greaterThan(0));
      // A scroll that wanders a little sideways too.
      await _swipe(tester, const Offset(40, 300));
      await tester.pumpAndSettle();
      expect(steps, isEmpty);
    });

    testWidgets('a swipe does not scroll the list', (tester) async {
      final steps = <bool>[];
      await tester.pumpWidget(_host(steps: steps));

      await _swipe(tester, const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(steps, [true]);
      expect(_scrolled(tester), 0);
    });

    testWidgets('a tap on a row still reaches the row', (tester) async {
      final steps = <bool>[];
      final taps = <int>[];
      await tester.pumpWidget(_host(steps: steps, taps: taps));

      await tester.tap(find.text('row 1'));
      await tester.pump();
      expect(taps, [1]);
      expect(steps, isEmpty);
    });

    testWidgets('a swipe that starts on a row is not a tap on it', (
      tester,
    ) async {
      final steps = <bool>[];
      final taps = <int>[];
      await tester.pumpWidget(_host(steps: steps, taps: taps));

      await tester.fling(find.text('row 1'), const Offset(160, 0), 1000);
      await tester.pump();
      expect(steps, [true]);
      expect(taps, isEmpty);
    });

    testWidgets('does nothing while it is not enabled', (tester) async {
      final steps = <bool>[];
      await tester.pumpWidget(_host(steps: steps, enabled: false));

      await _swipe(tester, const Offset(160, 0));
      await _swipe(tester, const Offset(-160, 0));
      expect(steps, isEmpty);

      // And works as soon as it is.
      await tester.pumpWidget(_host(steps: steps));
      await _swipe(tester, const Offset(160, 0));
      expect(steps, [true]);
    });

    testWidgets('two fingers are not a swipe, and the next touch is one again', (
      tester,
    ) async {
      final steps = <bool>[];
      await tester.pumpWidget(_host(steps: steps));

      final first = await tester.startGesture(
        const Offset(100, 300),
        pointer: 1,
      );
      final second = await tester.startGesture(
        const Offset(300, 300),
        pointer: 2,
      );
      for (var i = 1; i <= 8; i++) {
        await first.moveBy(
          const Offset(25, 0),
          timeStamp: Duration(milliseconds: 10 * i),
        );
      }
      await first.up(timeStamp: const Duration(milliseconds: 90));
      await second.up();
      await tester.pump();
      expect(steps, isEmpty);

      await _swipe(tester, const Offset(160, 0));
      expect(steps, [true]);
    });

    testWidgets('a touch that is cancelled is forgotten', (tester) async {
      final steps = <bool>[];
      await tester.pumpWidget(_host(steps: steps));

      final gesture = await tester.startGesture(const Offset(100, 300));
      for (var i = 1; i <= 8; i++) {
        await gesture.moveBy(
          const Offset(25, 0),
          timeStamp: Duration(milliseconds: 10 * i),
        );
      }
      await gesture.cancel();
      await tester.pump();
      expect(steps, isEmpty);

      await _swipe(tester, const Offset(-160, 0));
      expect(steps, [false]);
    });
  });
}
