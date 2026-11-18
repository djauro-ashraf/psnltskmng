import 'package:flutter/widgets.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/reading_banners.dart';

/// What the Details view puts in the Details dropdowns of the stream.
///
/// The Details view is the Words stream (`WordsStreamView`) with another card:
/// an ayah shows only its word by word and a Details dropdown, and the banners
/// (surah, juz, ch, page) get a Details dropdown of their own. What goes in
/// those dropdowns is browse knowledge (the state of a page, the notes of a
/// surah), which the shared widgets do not know, so the reader gives it here as
/// two builders.
///
/// A [WordsStreamView] given a [StreamDetails] is in Details mode; without one
/// it is the Words view.
///
/// Rows of the stream are never changing height under the reader: a builder
/// gives a body whose height is known on its first frame (a value that is not
/// there yet is a short placeholder, not a missing line).
class StreamDetails {
  const StreamDetails({required this.ayah, required this.banner});

  /// The body of the Details dropdown of the card of [ayah].
  final Widget Function(BuildContext context, AyahRef ayah) ayah;

  /// The body of the Details dropdown under [banner]: what the groups that start
  /// there say about themselves (a surah, a juz, a ch, a page). Null when the
  /// banner has no group to speak of (a hizb or a ruku that starts nothing
  /// else): no dropdown is drawn under it.
  final Widget? Function(BuildContext context, ReadingBanner banner) banner;
}
