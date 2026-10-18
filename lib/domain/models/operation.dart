/// M, R and L are operations performed on pages. They are never states.
enum Operation {
  m,
  r,

  /// R plus a marker: only ever logged by the user, never proposed. A
  /// successful L does everything a successful R does to the page and also
  /// sets the page's last-L day (see `LRules`). The marker is an indication
  /// for the user; no rule, planner or cost reads it.
  l;

  /// The operation whose effect on a page this one has: R for L, itself for M
  /// and R. Used where an L counts as the R it contains (matching a log to
  /// what was planned, what the AI is shown, what an L costs).
  Operation get baseOperation => this == Operation.l ? Operation.r : this;
}

/// What a page keeps of its progress when it recovers from F. The planner (or
/// AI) may choose among these; none of them can change the page's state.
enum ProgressPenalty {
  none,
  halve,
  reset;

  int apply(int units) => switch (this) {
    ProgressPenalty.none => units,
    ProgressPenalty.halve => units ~/ 2,
    ProgressPenalty.reset => 0,
  };
}
