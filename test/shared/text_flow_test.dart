import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/core/theme/page_state_colors.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/shared/widgets/page_state_widgets.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// The RGBA word of [color], as the bytes of a rendered image give it.
int _rgba(Color color) {
  final argb = color.toARGB32();
  return ((argb & 0x00FFFFFF) << 8) | ((argb >> 24) & 0xFF);
}

void main() {
  group('TextFlow', () {
    testWidgets('runs right to left when nothing sets it', (tester) async {
      TextDirection? seen;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = context.textFlow;
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, TextDirection.rtl);
    });

    testWidgets('follows the nearest TextFlow and its changes', (tester) async {
      final seen = <TextDirection>[];
      Widget app(TextDirection direction) => TextFlow(
        direction: direction,
        child: Builder(
          builder: (context) {
            seen.add(context.textFlow);
            return const SizedBox.shrink();
          },
        ),
      );

      await tester.pumpWidget(app(TextDirection.ltr));
      await tester.pumpWidget(app(TextDirection.rtl));

      expect(seen, [TextDirection.ltr, TextDirection.rtl]);
    });
  });

  group('PageSpine', () {
    // 20 pages: the first five are C, the other fifteen ND, so the strip is a
    // colored block (a quarter of it) at the end the first page is on, and ND
    // everywhere else. The strip is 100 px wide: the block is 25 px.
    final states = [
      for (var page = 1; page <= 20; page++)
        page <= 5 ? PageState.c : PageState.nd,
    ];

    /// The pixel at the left (x = 12) and the right (x = 88) of the strip.
    Future<({int left, int right})> sample(
      WidgetTester tester,
      TextDirection direction,
    ) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(
              child: TextFlow(
                direction: direction,
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 100,
                    child: PageSpine(states: states, height: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final result = await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = (await image.toByteData())!;
        int pixel(int x, int y) => data.getUint32((y * image.width + x) * 4);
        return (left: pixel(12, 7), right: pixel(88, 7));
      });
      return result!;
    }

    testWidgets('puts page 1 on the right when the text runs right to left', (
      tester,
    ) async {
      final c = _rgba(PageStateColors.light.of(PageState.c));
      final nd = _rgba(PageStateColors.light.of(PageState.nd));

      final pixels = await sample(tester, TextDirection.rtl);

      expect(pixels.right, c);
      expect(pixels.left, nd);
    });

    testWidgets('puts page 1 on the left when the text runs left to right', (
      tester,
    ) async {
      final c = _rgba(PageStateColors.light.of(PageState.c));
      final nd = _rgba(PageStateColors.light.of(PageState.nd));

      final pixels = await sample(tester, TextDirection.ltr);

      expect(pixels.left, c);
      expect(pixels.right, nd);
    });
  });
}
