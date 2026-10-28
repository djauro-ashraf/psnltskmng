import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_providers.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/models/footnote_text.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/quran_notice.dart';

/// The Words side of the Quran for one page: every ayah of the page with its
/// whole Arabic text, then each of its words with the English under it, then
/// the translation the reader chose (its footnote markers open the footnote). Reads the downloaded words and
/// translations; when they are not there it says so and offers the download.
class WordsPageView extends ConsumerWidget {
  const WordsPageView({super.key, required this.page});

  /// 1 to 604.
  final int page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return ref
        .watch(wordsPageProvider(page))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => QuranNotice(message: l10n.mushafBroken),
          data: (words) => words == null
              ? QuranNotice(message: l10n.wordsNotInstalled)
              : _WordsList(page: page, words: words),
        );
  }
}

class _WordsList extends ConsumerWidget {
  const _WordsList({required this.page, required this.words});

  final int page;
  final PageWords words;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textFont = ref.watch(mushafTextFontProvider).value;
    final translation = ref.watch(translationPageProvider(page)).value;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.xxl,
      ),
      children: [
        const _TranslationPicker(),
        for (final ayah in words.ayahs)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: _AyahCard(
              ayah: ayah,
              translation: translation?[ayah.key],
              fontFamily: textFont,
            ),
          ),
      ],
    );
  }
}

/// The downloaded translations as chips: tap one to read it. When none is
/// downloaded, a hint.
class _TranslationPicker extends ConsumerWidget {
  const _TranslationPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final installed = ref.watch(installedTranslationsProvider).value ?? const [];
    final selected = ref.watch(selectedTranslationIdProvider).value;
    if (installed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          l10n.wordsNoTranslation,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          l10n.wordsTranslation,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (final pack in installed)
          ChoiceChip(
            label: Text(pack.title),
            selected: pack.id == selected,
            onSelected: (_) =>
                ref.read(translationChoiceProvider.notifier).set(pack.id),
          ),
      ],
    );
  }
}

/// One ayah: its number, the whole Arabic text, the words with their English
/// under them, and the translation.
class _AyahCard extends StatelessWidget {
  const _AyahCard({
    required this.ayah,
    required this.translation,
    required this.fontFamily,
  });

  final AyahWords ayah;
  final TranslationText? translation;

  /// The Unicode Arabic font, null for the platform's.
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.panel),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.75),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ayah.key,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // The whole ayah, as it is read.
            Text(
              ayah.arabic,
              textDirection: TextDirection.rtl,
              locale: const Locale('ar'),
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 26,
                height: 1.9,
                color: scheme.onSurface,
              ),
            ),
            const Divider(height: AppSpacing.xl),
            // Word by word: the Arabic, and under it what it means.
            Wrap(
              textDirection: TextDirection.rtl,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                for (final word in ayah.words)
                  _WordCell(word: word, fontFamily: fontFamily),
              ],
            ),
            if (translation != null && translation!.text.isNotEmpty) ...[
              const Divider(height: AppSpacing.xl),
              _TranslationBody(translation: translation!),
            ],
          ],
        ),
      ),
    );
  }
}

class _WordCell extends StatelessWidget {
  const _WordCell({required this.word, required this.fontFamily});

  final WordGloss word;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 110),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word.arabic,
            textDirection: TextDirection.rtl,
            locale: const Locale('ar'),
            style: TextStyle(
              fontFamily: fontFamily,
              fontSize: 22,
              height: 1.6,
              color: scheme.onSurface,
            ),
          ),
          if (word.gloss.isNotEmpty)
            Text(
              word.gloss,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// A translation, with its footnote markers as small raised numbers: tap one to
/// read the footnote in a sheet that closes with a swipe or a tap outside it.
/// A reader who does not want the notes just reads past the numbers.
class _TranslationBody extends StatelessWidget {
  const _TranslationBody({required this.translation});

  final TranslationText translation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        style: theme.textTheme.bodyLarge,
        children: [
          for (final part in FootnoteText.parse(translation.text))
            switch (part) {
              PlainPart(:final text) => TextSpan(text: text),
              FootnotePart(:final id, :final label) => WidgetSpan(
                alignment: PlaceholderAlignment.top,
                child: _FootnoteMark(
                  label: label,
                  footnote: translation.footnotes[id],
                ),
              ),
            },
        ],
      ),
    );
  }
}

class _FootnoteMark extends StatelessWidget {
  const _FootnoteMark({required this.label, required this.footnote});

  final String label;

  /// The text of the footnote; null when the pack has none for this marker (the
  /// number is then only printed).
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasNote = footnote != null && footnote!.trim().isNotEmpty;
    final text = Text(
      label,
      style: theme.textTheme.labelSmall?.copyWith(
        color: hasNote ? scheme.primary : scheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      ),
    );
    final note = hasNote ? footnote : null;
    if (note == null) return Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: text);
    return Semantics(
      button: true,
      label: '${context.l10n.wordsFootnote} $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _show(context, note),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: text,
        ),
      ),
    );
  }

  void _show(BuildContext context, String note) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.6,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${l10n.wordsFootnote} $label',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(note, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
        );
      },
    );
  }
}
