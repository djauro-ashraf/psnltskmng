import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/theme/app_theme.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/features/browse/presentation/widgets/ayah_copy_sheet.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_providers.dart';
import 'package:personaltskmng/mushaf/data/mushaf_source.dart';
import 'package:personaltskmng/mushaf/models/mushaf_page.dart';
import 'package:personaltskmng/quran_data/controller/auto_read_provider.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';
import 'package:personaltskmng/quran_data/models/ayah_copy.dart';
import 'package:personaltskmng/quran_data/models/reader_entry.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';
import 'package:personaltskmng/shared/widgets/mushaf_page_view.dart';
import 'package:personaltskmng/shared/widgets/text_flow.dart';

/// A request to put the Mushaf on a page, and to tint the line of an ayah on it
/// (the jump of the Go to sheet). A new object each time, so asking for the same
/// page twice works.
final class MushafJump {
  MushafJump(this.page, {this.ayah});

  final int page;

  /// The ayah (`2:255`) whose first line on the page is tinted for a moment.
  final String? ayah;
}

/// The Mushaf side of the reader: the pages as printed, swiped like a book (with
/// the text running right to left, page 1 is on the right).
///
/// - Inside a [limit] (the unit the reader was entered through) the swiping
///   stays inside its pages, and after the last one there is a card, "End of s 2
///   · continue to s 3", instead of a wall. Tapping it removes the limit and
///   goes on page by page ([onReleaseLimit] with the next page).
/// - A tap on a word selects its ayah: its words are tinted and a small bar
///   offers Tafsir (only once a tafsir is downloaded), Words and Copy. A tap on
///   the empty room of the page (or its margin) still clears and brings back the
///   top bar ([onToggleBar]) and also closes the selection.
/// - A jump tints the line of the ayah for 1.5 s (still, with "reduce motion").
class MushafReader extends ConsumerStatefulWidget {
  const MushafReader({
    super.key,
    required this.jump,
    required this.limit,
    required this.onPage,
    required this.onOpenWords,
    required this.onTafsir,
    this.onAskAi,
    required this.onReleaseLimit,
    required this.onToggleBar,
  });

  final MushafJump jump;
  final ReaderLimit? limit;

  /// The page in front of the reader changed.
  final void Function(int page) onPage;

  /// "Words" in the selection bar: read this ayah in Words.
  final void Function(AyahRef ayah) onOpenWords;

  /// "Tafsir" in the selection bar.
  final void Function(AyahRef ayah) onTafsir;

  /// "Ask AI" in the selection bar.
  final void Function(AyahRef ayah)? onAskAi;

  /// The end card was tapped: the limit is gone, go on at [nextPage].
  final void Function(int nextPage) onReleaseLimit;

  final VoidCallback onToggleBar;

  @override
  ConsumerState<MushafReader> createState() => _MushafReaderState();
}

class _MushafReaderState extends ConsumerState<MushafReader>
    with SingleTickerProviderStateMixin {
  late PageController _controller;
  late int _page;
  String? _selected;
  String? _highlight;
  Timer? _highlightTimer;

  Ticker? _autoReadTicker;
  Duration _lastTick = Duration.zero;
  Duration _dwellElapsed = Duration.zero;
  double _dwellProgress = 0.0;
  bool _nextPagePreloaded = false;

  int get _first => widget.limit?.firstPage ?? 1;
  int get _count => widget.limit == null
      ? MushafPage.pageCount
      : widget.limit!.lastPage - widget.limit!.firstPage + 1;
  int get _itemCount => _count + (widget.limit == null ? 0 : 1);

  int _indexOf(int page, ReaderLimit? limit) =>
      math.max(0, page - (limit?.firstPage ?? 1));

  @override
  void initState() {
    super.initState();
    _page = widget.jump.page;
    _controller = PageController(initialPage: _indexOf(_page, widget.limit));
    _startHighlight(widget.jump.ayah);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(autoReadProvider).playing) {
        _updateAutoReadTicker(true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MushafReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final jumped = widget.jump != oldWidget.jump;
    if (oldWidget.limit != widget.limit) {
      // The pages the pager reaches changed: a pager of its own, which opens on
      // the right page at once (no frame on the wrong one).
      final old = _controller;
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      if (jumped) _page = widget.jump.page;
      _controller = PageController(initialPage: _indexOf(_page, widget.limit));
      _selected = null;
      _resetDwell();
    } else if (jumped) {
      _page = widget.jump.page;
      _selected = null;
      _resetDwell();
      final index = _indexOf(_page, widget.limit);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_controller.hasClients) _controller.jumpToPage(index);
      });
    }
    if (jumped) _startHighlight(widget.jump.ayah);
  }

  @override
  void dispose() {
    _autoReadTicker?.dispose();
    _highlightTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _resetDwell() {
    _dwellElapsed = Duration.zero;
    _dwellProgress = 0.0;
    _nextPagePreloaded = false;
  }

  int _wordCountForPage(int page) {
    final pageData = ref.read(mushafPageProvider(page)).value;
    if (pageData is MushafReady) {
      var count = 0;
      for (final line in pageData.page.lines) {
        count += line.words.length;
      }
      return count > 0 ? count : 128;
    }
    return 128;
  }

  void _updateAutoReadTicker(bool playing) {
    if (playing) {
      if (_autoReadTicker == null) {
        _lastTick = Duration.zero;
        _autoReadTicker = createTicker(_onAutoReadTick)..start();
      } else if (!_autoReadTicker!.isTicking) {
        _lastTick = Duration.zero;
        _autoReadTicker!.start();
      }
    } else {
      _autoReadTicker?.stop();
      _lastTick = Duration.zero;
      if (_dwellProgress != 0.0 && mounted) {
        setState(() => _dwellProgress = 0.0);
      }
    }
  }

  void _onAutoReadTick(Duration elapsed) {
    if (!mounted) return;
    if (_lastTick == Duration.zero) {
      _lastTick = elapsed;
      return;
    }
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;

    final clampedDtMs = math.min(100, dt.inMilliseconds);
    if (clampedDtMs <= 0) return;

    final autoRead = ref.read(autoReadProvider);
    if (!autoRead.playing) {
      _updateAutoReadTicker(false);
      return;
    }

    final words = _wordCountForPage(_page);
    final totalDwell = autoRead.pacer.pageDwell(words);

    _dwellElapsed += Duration(milliseconds: clampedDtMs);
    final progress =
        (_dwellElapsed.inMilliseconds / totalDwell.inMilliseconds).clamp(0.0, 1.0);

    if (progress >= 0.8 && !_nextPagePreloaded) {
      _nextPagePreloaded = true;
      if (_page < MushafPage.pageCount) {
        unawaited(ref.read(mushafPageProvider(_page + 1).future));
      }
    }

    if (progress >= 1.0) {
      _dwellElapsed = Duration.zero;
      _nextPagePreloaded = false;
      final limit = widget.limit;
      if (_page >= MushafPage.pageCount ||
          (limit != null && _page >= limit.lastPage)) {
        ref.read(autoReadProvider.notifier).pause();
        setState(() => _dwellProgress = 0.0);
      } else {
        if (_controller.hasClients) {
          _controller.nextPage(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut,
          );
        }
        setState(() => _dwellProgress = 0.0);
      }
    } else {
      setState(() => _dwellProgress = progress);
    }
  }

  void _startHighlight(String? ayah) {
    _highlightTimer?.cancel();
    _highlight = ayah;
    if (ayah == null) return;
    _highlightTimer = Timer(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _highlight = null);
    });
  }

  void _onPageChanged(int index) {
    _resetDwell();
    if (index >= _count) {
      // The end card.
      setState(() => _selected = null);
      return;
    }
    final page = _first + index;
    if (page == _page && _selected == null) return;
    setState(() {
      _page = page;
      _selected = null;
    });
    widget.onPage(page);
  }

  void _onEmptyTap() {
    if (_selected != null) setState(() => _selected = null);
    widget.onToggleBar();
  }

  Future<void> _copy(AyahRef ayah) async {
    final l10n = context.l10n;
    try {
      final words = await ref.read(surahWordsProvider(ayah.surah).future);
      final text = words == null || ayah.ayah > words.length
          ? ayah.key
          : AyahCopy.build([
              AyahCopyInput(ayah: words[ayah.ayah - 1]),
            ], CopyRecipe.arabicOnly).text;
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) showAppSnackBar(context, l10n.readerCopied);
    } catch (_) {
      if (mounted) showAppSnackBar(context, l10n.mushafBroken, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      autoReadProvider.select((s) => s.playing),
      (prev, next) => _updateAutoReadTicker(next),
    );

    final limit = widget.limit;
    final tafsirOn = ref.watch(
      tafsirSourcesProvider.select((v) => v.value?.isNotEmpty ?? false),
    );
    final selected = _selected == null ? null : AyahRef.tryParse(_selected!);
    return Stack(
      children: [
        PageView.builder(
          // A pager of its own for each set of pages (see `didUpdateWidget`).
          key: ValueKey(limit),
          reverse: context.textRunsRightToLeft,
          controller: _controller,
          itemCount: _itemCount,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            if (limit != null && index >= _count) {
              return _EndCard(
                limit: limit,
                onContinue: () => widget.onReleaseLimit(limit.lastPage + 1),
              );
            }
            final page = _first + index;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onEmptyTap,
              child: MushafPageView(
                page: page,
                selectedAyah: _selected,
                highlightAyah: _highlight,
                onAyahTap: (ayah) {
                  ref.read(autoReadProvider.notifier).pause();
                  setState(() => _selected = ayah);
                },
              ),
            );
          },
        ),
        if (_dwellProgress > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 3,
              child: LinearProgressIndicator(
                value: _dwellProgress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        if (selected != null)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: _SelectionBar(
                ayah: selected,
                tafsir: tafsirOn ? () => widget.onTafsir(selected) : null,
                onWords: () => widget.onOpenWords(selected),
                onCopy: () => unawaited(_copy(selected)),
                onCopySheet: () => showAyahCopySheet(context, ayah: selected),
                onAskAi: widget.onAskAi != null
                    ? () => widget.onAskAi!(selected)
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

/// The small bar of a selected ayah: Tafsir · Words · Copy. Tafsir is there only
/// once at least one tafsir is downloaded ([tafsir] is null before).
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.ayah,
    required this.tafsir,
    required this.onWords,
    required this.onCopy,
    this.onCopySheet,
    this.onAskAi,
  });

  final AyahRef ayah;
  final VoidCallback? tafsir;
  final VoidCallback onWords;
  final VoidCallback onCopy;
  final VoidCallback? onCopySheet;
  final VoidCallback? onAskAi;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = TextButton.styleFrom(
      minimumSize: const Size(56, 44),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
    );
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 3,
      shape: const StadiumBorder(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                ayah.key,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (tafsir != null)
              TextButton(
                style: style,
                onPressed: tafsir,
                child: Text(l10n.readerTafsir),
              ),
            TextButton(
              style: style,
              onPressed: onWords,
              child: Text(l10n.quranViewWords),
            ),
            TextButton(
              style: style,
              onPressed: onCopy,
              onLongPress: onCopySheet,
              child: Text(l10n.readerCopy),
            ),
            if (onAskAi != null)
              TextButton(
                style: style,
                onPressed: onAskAi,
                child: Text(l10n.copyItemAskAi),
              ),
          ],
        ),
      ),
    );
  }
}

/// The card after the last page of a limit: "End of s 2 · continue to s 3".
/// Tapping it removes the limit and carries on page by page, so the reader is
/// never stuck. At the very end of the Quran it only says so.
class _EndCard extends StatelessWidget {
  const _EndCard({required this.limit, required this.onContinue});

  final ReaderLimit limit;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final next = limit.nextNumber;
    final atEnd = limit.lastPage >= MushafPage.pageCount;
    final text = atEnd
        ? l10n.readerEndOfQuran
        : switch (limit.kind) {
            ReaderLimitKind.surah when next != null => l10n.readerEndOfS(
              limit.number,
              next,
            ),
            ReaderLimitKind.ch when next != null => l10n.readerEndOfCh(
              limit.number,
              next,
            ),
            ReaderLimitKind.juz when next != null => l10n.readerEndOfJuz(
              limit.number,
              next,
            ),
            ReaderLimitKind.part ||
            ReaderLimitKind.range => l10n.readerEndOfPart,
            _ => l10n.readerEndOfQuran,
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Material(
          color: scheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.panel),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.panel),
            onTap: atEnd ? null : onContinue,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.xl,
              ),
              child: Semantics(
                button: !atEnd,
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: AppTheme.serif,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
