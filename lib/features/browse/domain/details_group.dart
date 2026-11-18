import 'package:personaltskmng/features/browse/domain/browse_index.dart';

/// A group the Details view can speak about: a surah, a juz, a ch or a page.
///
/// It is what the Details dropdowns (under an ayah and under a banner) and the
/// group sheet they open are about. A [BrowseScope] says the same for a surah
/// or a ch, but it has no juz and no page, and the Details view needs all four.
/// Pure Dart.
sealed class DetailsGroup {
  const DetailsGroup();
}

/// One surah (1 to 114).
final class SurahGroup extends DetailsGroup {
  const SurahGroup(this.s);

  final int s;

  @override
  bool operator ==(Object other) => other is SurahGroup && other.s == s;

  @override
  int get hashCode => Object.hash('surah', s);
}

/// One juz (1 to 30).
final class JuzGroup extends DetailsGroup {
  const JuzGroup(this.juz);

  final int juz;

  @override
  bool operator ==(Object other) => other is JuzGroup && other.juz == juz;

  @override
  int get hashCode => Object.hash('juz', juz);
}

/// One ch (1 to 71).
final class ChGroup extends DetailsGroup {
  const ChGroup(this.ch);

  final int ch;

  @override
  bool operator ==(Object other) => other is ChGroup && other.ch == ch;

  @override
  int get hashCode => Object.hash('ch', ch);
}

/// One page (1 to 604).
final class PageGroup extends DetailsGroup {
  const PageGroup(this.page);

  final int page;

  @override
  bool operator ==(Object other) => other is PageGroup && other.page == page;

  @override
  int get hashCode => Object.hash('page', page);
}

/// The scope of a surah or a ch group, for the lookups that are about scopes
/// (the state summary, the parts, the notes); null for a juz or a page.
BrowseScope? scopeOfGroup(DetailsGroup group) => switch (group) {
  SurahGroup(:final s) => SScope(s),
  ChGroup(:final ch) => ChScope(ch),
  JuzGroup() => null,
  PageGroup() => null,
};
