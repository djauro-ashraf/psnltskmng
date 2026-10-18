/// State of a page. ND, D1-D3, C and F1-F3 are domain terms: never renamed,
/// expanded or translated.
enum PageState { nd, d1, d2, d3, c, f1, f2, f3 }

extension PageStateX on PageState {
  bool get isD =>
      this == PageState.d1 || this == PageState.d2 || this == PageState.d3;

  bool get isF =>
      this == PageState.f1 || this == PageState.f2 || this == PageState.f3;

  /// 1..3 for F1..F3, 0 for every other state.
  int get fLevel => switch (this) {
    PageState.f1 => 1,
    PageState.f2 => 2,
    PageState.f3 => 3,
    _ => 0,
  };

  /// Whether pages in this state are part of a D range. F3 is not: an F3
  /// region inside the main D range splits it.
  bool get belongsToDRange => this != PageState.nd && this != PageState.f3;
}
