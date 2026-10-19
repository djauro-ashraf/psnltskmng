import 'package:flutter/widgets.dart';

/// The direction the text (the pages of the book) runs on screen, for every
/// widget below it. The app root puts it above the whole app from the
/// "Reading direction" setting; widgets read it with `context.textFlow`.
///
/// It is not the language direction: the book is read right to left whatever
/// language the interface is in, so [Directionality] is left alone. Only
/// things drawn in text order ask for it (the page strips, the page cells,
/// paging and its arrows). Minutes, budgets and the rest of the interface do
/// not.
class TextFlow extends InheritedWidget {
  const TextFlow({super.key, required this.direction, required super.child});

  /// [TextDirection.rtl]: page 1 on the right, later pages toward the left.
  final TextDirection direction;

  /// The direction in effect here. Without a [TextFlow] above (a widget shown
  /// on its own, in a test) it is right to left, the setting's default.
  static TextDirection of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TextFlow>()?.direction ??
        TextDirection.rtl;
  }

  @override
  bool updateShouldNotify(TextFlow oldWidget) =>
      direction != oldWidget.direction;
}

extension TextFlowX on BuildContext {
  /// How the text runs here (see [TextFlow]). Rebuilds the widget when the
  /// setting changes.
  TextDirection get textFlow => TextFlow.of(this);

  /// True when the text runs right to left: page 1 on the right.
  bool get textRunsRightToLeft => textFlow == TextDirection.rtl;
}
