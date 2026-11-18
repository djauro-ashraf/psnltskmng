/// The three parts of an ayah card in the Words view, top to bottom: the whole
/// ayah in Arabic, the same ayah word by word (each word with its English under
/// it), and the translation.
enum AyahSection { arabic, words, translation }

/// Which sections of the ayah card are open and which are closed.
///
/// ONE value for the whole reader, not one per ayah: closing the translation on
/// one ayah closes it on every ayah (and it stays closed in the next session),
/// so a reader can keep only what he wants in front of him. A closed section
/// keeps its title row, so it can be opened again from any card.
///
/// Everything is open until the reader closes something. The value keeps what is
/// CLOSED (not what is open), so a section added in a later version starts open.
/// Pure Dart, immutable, compared by value.
final class AyahSections {
  const AyahSections._(this._closed);

  /// Every section open: how a reader starts.
  static const AyahSections allOpen = AyahSections._(0);

  /// Every section open except [closed].
  factory AyahSections.closing(Iterable<AyahSection> closed) {
    var mask = 0;
    for (final section in closed) {
      mask |= _bit(section);
    }
    return AyahSections._(mask);
  }

  /// Reads what [encode] wrote. Anything that means nothing (null, empty, a name
  /// that is not a section) is left out, so a damaged value reads as "open".
  factory AyahSections.decode(String? text) {
    if (text == null || text.isEmpty) return allOpen;
    final byName = AyahSection.values.asNameMap();
    return AyahSections.closing([
      for (final part in text.split(',')) ?byName[part.trim()],
    ]);
  }

  // One bit per section, by its place in the enum.
  final int _closed;

  static int _bit(AyahSection section) => 1 << section.index;

  bool isOpen(AyahSection section) => _closed & _bit(section) == 0;

  bool isClosed(AyahSection section) => !isOpen(section);

  /// Nothing is closed.
  bool get isAllOpen => _closed == 0;

  /// The closed sections, in the order of the card.
  List<AyahSection> get closed => [
    for (final section in AyahSection.values)
      if (isClosed(section)) section,
  ];

  /// The same, with [section] opened if it was closed and closed if it was open.
  AyahSections toggled(AyahSection section) =>
      AyahSections._(_closed ^ _bit(section));

  /// The same, with [section] open ([open] true) or closed.
  AyahSections withOpen(AyahSection section, bool open) => AyahSections._(
    open ? _closed & ~_bit(section) : _closed | _bit(section),
  );

  /// The closed sections by name, comma between: `words,translation`. Empty when
  /// everything is open.
  String encode() => closed.map((section) => section.name).join(',');

  @override
  bool operator ==(Object other) =>
      other is AyahSections && other._closed == _closed;

  @override
  int get hashCode => _closed.hashCode;

  @override
  String toString() => 'AyahSections(closed: ${encode()})';
}
