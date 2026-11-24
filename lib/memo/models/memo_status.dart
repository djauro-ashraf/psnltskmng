/// Where an ayah stands. The same eight states as before, with names instead of
/// letters:
///
/// | name          | was | meaning                                              |
/// |---------------|-----|------------------------------------------------------|
/// | notLearned    | ND  | never reached consolidated: new, or forgotten again  |
/// | learning1..3  | D1-3| the learning levels, reached by reviewing            |
/// | consolidated  | C   | solid                                                |
/// | fading1, 2    | F1-2| left without review: a warning (one review restores) |
/// | forgotten     | F3  | consolidated once, then lost: needs memorising again |
///
/// A fading ayah remembers the level it faded from.
enum MemoStatus {
  notLearned,
  learning1,
  learning2,
  learning3,
  consolidated,
  fading1,
  fading2,
  forgotten;

  /// The three learning levels.
  bool get isLearning =>
      this == learning1 || this == learning2 || this == learning3;

  /// Fading 1 or 2 (a warning; forgotten is a state of its own).
  bool get isFading => this == fading1 || this == fading2;

  /// Memorise (M) is only taken on ayahs that are not learned or forgotten.
  bool get acceptsMemorise => this == notLearned || this == forgotten;

  /// Review (R) is only taken on learning, consolidated and fading ayahs.
  bool get acceptsReview => !acceptsMemorise;

  /// The learning level, 1 to 3, or null for the other states.
  int? get learningLevel => switch (this) {
    learning1 => 1,
    learning2 => 2,
    learning3 => 3,
    _ => null,
  };

  /// How firmly a *unit* of ayahs holds, from 0 (forgotten) to 4 (consolidated),
  /// used to name the worst state of a group. Fading counts at the level it
  /// faded from, which the caller knows; not learned has no level.
  static MemoStatus ofLevel(int? level) => switch (level) {
    null => notLearned,
    0 => forgotten,
    1 => learning1,
    2 => learning2,
    3 => learning3,
    _ => consolidated,
  };

  /// The learning status for [level] (1 to 3).
  static MemoStatus learning(int level) => switch (level) {
    1 => learning1,
    2 => learning2,
    _ => learning3,
  };
}
