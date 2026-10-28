import 'package:flutter/material.dart';
import 'package:personaltskmng/domain/reference/surah_names.dart';

/// The Arabic name of an s, drawn right to left whatever the interface
/// language is (the name is Arabic, the screen around it may not be).
///
/// The app's bundled fonts have no Arabic letters, so the platform's own
/// Arabic font draws them; `locale` makes Flutter pick it.
class SurahArabicText extends StatelessWidget {
  const SurahArabicText(this.s, {super.key, this.style});

  /// The s (1 to [SurahNames.count]).
  final int s;

  /// Defaults to the theme's `titleLarge`.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      SurahNames.of(s).arabic,
      style: style ?? Theme.of(context).textTheme.titleLarge,
      textDirection: TextDirection.rtl,
      locale: const Locale('ar'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
