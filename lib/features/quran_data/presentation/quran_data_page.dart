import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/models/quran_pack.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/pill_toggle.dart';

/// Where the Quran is downloaded: the lines of the pages, the page fonts, the
/// words, and the translations. Each part is downloaded, stopped or deleted on
/// its own; once downloaded it works without internet.
class QuranDataPage extends ConsumerStatefulWidget {
  const QuranDataPage({super.key});

  @override
  ConsumerState<QuranDataPage> createState() => _QuranDataPageState();
}

class _QuranDataPageState extends ConsumerState<QuranDataPage> {
  late final TextEditingController _address = TextEditingController(
    text: ref.read(manifestUrlProvider),
  );

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    await ref.read(manifestUrlProvider.notifier).set(_address.text);
    ref.invalidate(quranManifestProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final manifest = ref.watch(quranManifestProvider);
    final fonts = ref.watch(quranFontPacksProvider);
    final remote = manifest.value?.packs ?? const <QuranPack>[];
    final edition = ref.watch(mushafEditionProvider);
    QuranPack? layout;
    for (final pack in remote) {
      if (pack.id == edition.layoutPackId) layout = pack;
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.quranDataTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formMaxWidth,
          ),
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(l10n.quranDataIntro),
              const SizedBox(height: AppSpacing.lg),
              _AddressCard(controller: _address, onSave: _saveAddress),
              const SizedBox(height: AppSpacing.lg),
              const _EditionCard(),
              const SizedBox(height: AppSpacing.lg),
              _Heading(l10n.quranDataSectionPages),
              if (layout != null)
                PackTile(pack: layout)
              else if (manifest.value != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    l10n.quranEditionMissing,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              for (final pack in fonts) PackTile(pack: pack),
              const SizedBox(height: AppSpacing.lg),
              _Heading(l10n.quranDataSectionText),
              for (final pack in remote)
                if (pack.kind == QuranPackKind.words ||
                    pack.kind == QuranPackKind.translation)
                  PackTile(pack: pack),
              const SizedBox(height: AppSpacing.xl),
              Text(
                l10n.quranDataCredits,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

/// The print of the mushaf the reader follows. Both have 604 pages; a few pages
/// hold other ayahs in the second.
class _EditionCard extends ConsumerWidget {
  const _EditionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final edition = ref.watch(mushafEditionProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.quranEditionTitle, style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: PillToggle<MushafEdition>(
                horizontalPadding: AppSpacing.lg,
                options: [
                  (MushafEdition.v1, l10n.quranEditionV1),
                  (MushafEdition.v2, l10n.quranEditionV2),
                ],
                value: edition,
                onChanged: (next) =>
                    ref.read(mushafEditionProvider.notifier).set(next),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              edition == MushafEdition.v1
                  ? l10n.quranEditionNoteV1
                  : l10n.quranEditionNoteV2,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The address of the pack list, and whether it could be read.
class _AddressCard extends ConsumerWidget {
  const _AddressCard({required this.controller, required this.onSave});

  final TextEditingController controller;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final manifest = ref.watch(quranManifestProvider);
    final address = ref.watch(manifestUrlProvider);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.quranDataAddressTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                hintText: l10n.quranDataAddressHint,
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonal(
                onPressed: onSave,
                child: Text(l10n.quranDataAddressSave),
              ),
            ),
            if (address.isEmpty)
              Text(
                l10n.quranDataNoAddress,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              manifest.when(
                loading: () => const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: LinearProgressIndicator(),
                ),
                error: (error, stack) => Text(
                  '${l10n.quranDataManifestError}\n$error',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                data: (value) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

/// One downloadable pack: what it is, how much of it is on the device, and the
/// button that fits (download, stop, delete).
class PackTile extends ConsumerWidget {
  const PackTile({super.key, required this.pack});

  final QuranPack pack;

  String _title(AppLocalizations l10n) => switch (pack.kind) {
    QuranPackKind.fonts => l10n.quranPackFontsTitle,
    QuranPackKind.textFont => l10n.quranPackTextFontTitle,
    _ => pack.title,
  };

  String _description(AppLocalizations l10n) => switch (pack.kind) {
    QuranPackKind.fonts => l10n.quranPackFontsDesc,
    QuranPackKind.textFont => l10n.quranPackTextFontDesc,
    _ => [
      if (pack.author.isNotEmpty) pack.author,
      if (pack.description.isNotEmpty) pack.description,
      ?_size(pack.totalBytes),
    ].join(' · '),
  };

  static String? _size(int? bytes) {
    if (bytes == null) return null;
    return bytes >= 1024 * 1024
        ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(bytes / 1024).round()} KB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = ref.read(quranDataControllerProvider.notifier);
    final state = ref.watch(quranDataControllerProvider);
    final status = ref.watch(packStatusProvider(pack)).value;
    final progress = state.progress[pack.id];
    final error = state.errors[pack.id];
    final description = _description(l10n);

    Widget action;
    if (progress != null) {
      action = TextButton(
        onPressed: () => controller.cancel(pack.id),
        child: Text(l10n.quranDataCancel),
      );
    } else if (status != null && status.complete) {
      action = TextButton(
        onPressed: () => controller.delete(pack),
        child: Text(l10n.quranDataDelete),
      );
    } else {
      action = FilledButton.tonal(
        onPressed: () => controller.install(pack),
        child: Text(l10n.quranDataDownload),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title(l10n), style: theme.textTheme.titleSmall),
                      if (description.isNotEmpty)
                        Text(
                          description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      if (status != null && status.complete)
                        Text(
                          l10n.quranDataDownloaded,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        )
                      else if (status != null && !status.none)
                        Text(
                          '${status.have} / ${status.total}',
                          style: theme.textTheme.labelMedium,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                action,
              ],
            ),
            if (progress != null) ...[
              const SizedBox(height: AppSpacing.sm),
              LinearProgressIndicator(value: progress),
            ],
            if (error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${l10n.quranDataFailed} $error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
