import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_providers.dart';
import 'package:personaltskmng/quran_data/controller/quran_prefs.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/controller/tafsir_providers.dart';
import 'package:personaltskmng/quran_data/models/page_content.dart';
import 'package:personaltskmng/quran_data/models/words_model.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/division_labels.dart';
import 'package:personaltskmng/shared/widgets/quran_notice.dart';
import 'package:personaltskmng/shared/widgets/words_rows.dart';

/// A request to put the Words stream on an ayah. A new object each time, so
/// asking for the same ayah twice works (a jump, a change of unit).
final class WordsJump {
  WordsJump(this.ayah, {this.highlight = false});

  final AyahRef ayah;

  /// The ayah is tinted for a moment when the stream lands on it (a jump from
  /// the Go to sheet); a plain opening is not.
  final bool highlight;
}

/// The Words side of the Quran: ONE continuous scroll over the ayahs, not a page
/// that is swiped away.
///
/// The reader's unit (a page, a ruku, a hizb, a juz, an s, a ch, the whole
/// Quran) decides the banners and where they are upgraded, and the ayah it
/// opens on; it does not decide where the scroll ends. When the end of a unit
/// is reached the next one is simply more rows below (and the previous one more
/// rows above): no sideways flip, no spinner, no scroll reset. This is done with
/// a scroll view that has a center: the rows after the opening ayah grow down,
/// the rows before it grow up, both made ahead of the viewport in small steps
/// (`WordsModel`) so that they are in place before they scroll into view.
///
/// ON A DEVICE TO CHECK (the seam could not be tried where this was written):
/// scroll through at least ten units on a mid-range phone, flinging over three
/// or more seams in a row and just after a jump, at 130% and 200% text, in light
/// and dark. Watch for a hitch, a blank gap or a jump at a seam. If it cannot be
/// made smooth, the fallback the reader asked for (and asked to be told about
/// first) is: stop the stream at the end of the unit with a tile "Next: Ruku
/// 35" that replaces the content with a fade of 150 ms at most. The pieces to
/// tune are [_prefetch], [_firstForward], [_firstBackward], [_step] and the
/// cache extent factor in `build`.
///
/// A new stream is made (the rows start again from the ayah at the top, so it
/// stays where it is) when [jump] or [unit] change, and when the translation or
/// the text size change; until the new rows are ready the old ones stay, so no
/// wrong content shows for a moment. It reports the ayah at the top of the
/// screen with [onTop], at most every 120 ms while scrolling.
class WordsStreamView extends ConsumerStatefulWidget {
  const WordsStreamView({
    super.key,
    required this.jump,
    required this.unit,
    required this.onTop,
    required this.onOpenInfo,
    required this.onTafsir,
    this.stop,
    this.onReleaseStop,
  });

  final WordsJump jump;
  final WordsUnit unit;

  /// The run the stream stops at, with a "Keep reading" tile (a part, a range);
  /// null: it only stops at the ends of the Quran.
  final AyahRange? stop;

  /// The ayah at the top of the screen changed.
  final void Function(AyahRef ayah) onTop;

  /// A surah banner (`surah`) or a juz banner (`juz`) was tapped.
  final void Function({int? surah, int? juz}) onOpenInfo;

  /// The Tafsir button of an ayah card was tapped.
  final void Function(AyahRef ayah) onTafsir;

  /// The reader tapped "Keep reading": the limit is gone.
  final VoidCallback? onReleaseStop;

  @override
  ConsumerState<WordsStreamView> createState() => _WordsStreamViewState();
}

/// The words of a surah are not downloaded.
class _WordsMissing implements Exception {
  const _WordsMissing();
}

class _WordsStreamViewState extends ConsumerState<WordsStreamView> {
  /// How many rows before the end of a list the next step is asked for.
  static const int _prefetch = 18;

  /// How many ayahs the first rows hold below and above the opening ayah.
  static const int _firstForward = 40;
  static const int _firstBackward = 16;

  /// How many ayahs a later step makes.
  static const int _step = 24;

  WordsModel? _model;
  int _generation = 0;

  // Changes only when a new stream is shown, so a rebuild while the next one is
  // being made never restarts the scroll view under the reader.
  int _shown = 0;
  GlobalKey _forwardKey = GlobalKey();
  GlobalKey _backwardKey = GlobalKey();
  final ScrollController _scroll = ScrollController();

  bool _forwardBusy = false;
  bool _backwardBusy = false;
  bool _missing = false;
  Object? _problem;

  // What the rows of the current stream were made with: the cards of a stream
  // never change under the reader, a new stream is made instead.
  String? _translationId;
  double _scale = 1;

  AyahRef? _top;
  AyahRef? _highlight;
  Timer? _highlightTimer;
  Timer? _topTimer;
  final ValueNotifier<double?> _fraction = ValueNotifier<double?>(null);

  @override
  void initState() {
    super.initState();
    _open(widget.jump.ayah, highlight: widget.jump.highlight);
  }

  @override
  void didUpdateWidget(covariant WordsStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.jump != oldWidget.jump) {
      _open(widget.jump.ayah, highlight: widget.jump.highlight);
    } else if (widget.unit != oldWidget.unit) {
      _open(_top ?? widget.jump.ayah);
    }
  }

  @override
  void dispose() {
    _generation++;
    _highlightTimer?.cancel();
    _topTimer?.cancel();
    _fraction.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // -- opening a stream ------------------------------------------------------

  /// Makes the data of a surah available before the rows of it are made (see
  /// `WordsModel.ready`): the words, and the translation of this stream.
  Future<void> _ready(int surah, String? translationId) async {
    final words = await _readWords(surah);
    if (words == null) throw const _WordsMissing();
    if (translationId != null) await _readTranslation(surah, translationId);
  }

  // The two reads below listen for a moment and let go at once: the data stays
  // for the keep-alive time after the last card of it went away (see
  // `quranSurahKeepAlive`), so five minutes of scrolling never hold all of it.
  Future<List<AyahWords>?> _readWords(int surah) async {
    final subscription = ref.listenManual(
      surahWordsProvider(surah).future,
      (previous, next) {},
    );
    try {
      return await subscription.read();
    } finally {
      subscription.close();
    }
  }

  Future<Map<String, TranslationText>?> _readTranslation(
    int surah,
    String id,
  ) async {
    final subscription = ref.listenManual(
      surahTranslationProvider((surah: surah, id: id)).future,
      (previous, next) {},
    );
    try {
      return await subscription.read();
    } finally {
      subscription.close();
    }
  }

  void _reopen() => _open(_top ?? widget.jump.ayah);

  Future<void> _open(AyahRef anchor, {bool highlight = false}) async {
    final generation = ++_generation;
    final locator = ref.read(pageLocatorProvider);
    final scale = QuranTextSize.factor(ref.read(textSizeProvider));
    WordsModel? model;
    String? translationId;
    try {
      translationId = await ref.read(selectedTranslationIdProvider.future);
      model = WordsModel(
        unit: widget.unit,
        locator: locator,
        ready: (surah) => _ready(surah, translationId),
        stop: widget.stop,
      );
      if (!await model.start(anchor)) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _model = null;
          _missing = true;
          _problem = null;
        });
        return;
      }
      await Future.wait([
        model.extendForward(_firstForward),
        model.extendBackward(_firstBackward),
      ]);
    } on _WordsMissing {
      if (!mounted || generation != _generation) return;
      setState(() {
        _model = null;
        _missing = true;
        _problem = null;
      });
      return;
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _model = null;
        _problem = error;
      });
      return;
    }
    if (!mounted || generation != _generation) return;
    setState(() {
      _model = model;
      _shown++;
      _translationId = translationId;
      _scale = scale;
      _forwardKey = GlobalKey();
      _backwardKey = GlobalKey();
      _forwardBusy = false;
      _backwardBusy = false;
      _missing = false;
      _problem = null;
      _highlight = highlight ? anchor : null;
    });
    _highlightTimer?.cancel();
    if (highlight) {
      _highlightTimer = Timer(
        AyahCard.highlightDuration + const Duration(milliseconds: 200),
        () {
          if (mounted) setState(() => _highlight = null);
        },
      );
    }
    _setTop(anchor, force: true);
  }

  // -- extending -------------------------------------------------------------

  /// Asks the model for the next step in one direction; the rows are there
  /// before the reader gets to the end of what is made. One step at a time per
  /// direction.
  void _extend({required bool forward}) {
    final model = _model;
    if (model == null) return;
    if (forward ? (_forwardBusy || model.forwardDone) : (_backwardBusy || model.backwardDone)) {
      return;
    }
    final generation = _generation;
    if (forward) {
      _forwardBusy = true;
    } else {
      _backwardBusy = true;
    }
    final step = forward ? model.extendForward(_step) : model.extendBackward(_step);
    step.then(
      (_) {
        if (!mounted || generation != _generation) return;
        setState(() {
          if (forward) {
            _forwardBusy = false;
          } else {
            _backwardBusy = false;
          }
        });
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _forwardBusy = false;
          _backwardBusy = false;
          if (error is _WordsMissing) {
            _missing = true;
          } else {
            _problem = error;
          }
        });
      },
    );
  }

  void _release({required bool forward}) {
    final model = _model;
    if (model == null) return;
    if (forward) {
      model.releaseForward();
    } else {
      model.releaseBackward();
    }
    widget.onReleaseStop?.call();
    setState(() {});
    _extend(forward: forward);
  }

  // -- the ayah at the top ---------------------------------------------------

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _topTimer ??= Timer(const Duration(milliseconds: 120), () {
        _topTimer = null;
        if (mounted) _checkTop();
      });
    }
    return false;
  }

  /// Finds the row at the top of the screen by asking the two lists which of
  /// their built rows covers the top edge (no row is measured by guessing), and
  /// reports its ayah.
  void _checkTop() {
    final model = _model;
    if (model == null || !_scroll.hasClients) return;
    final pixels = _scroll.position.pixels;
    final forward = pixels >= 0;
    final render = (forward ? _forwardKey : _backwardKey).currentContext
        ?.findRenderObject();
    if (render is! RenderSliverMultiBoxAdaptor) return;
    // Forward: the offset into the list. Backward: the list grows up from the
    // center, so the top edge is at `-pixels` from it.
    final target = forward ? pixels : -pixels;
    final list = forward ? model.forward : model.backward;
    int? found;
    RenderBox? child = render.firstChild;
    while (child != null) {
      final data = child.parentData;
      if (data is! SliverMultiBoxAdaptorParentData) return;
      final start = data.layoutOffset ?? 0;
      if (start + child.size.height > target) {
        found = data.index;
        break;
      }
      child = render.childAfter(child);
    }
    if (found == null || list.isEmpty) return;
    final ayah = _ayahNear(list, found < list.length ? found : list.length - 1);
    if (ayah != null) _setTop(ayah);
  }

  AyahRef? _ayahNear(List<StreamItem> list, int index) {
    for (var k = 0; k < 6; k++) {
      if (index + k < list.length) {
        final ayah = list[index + k].ayah;
        if (ayah != null) return ayah;
      }
      if (index - k >= 0) {
        final ayah = list[index - k].ayah;
        if (ayah != null) return ayah;
      }
    }
    return null;
  }

  void _setTop(AyahRef ayah, {bool force = false}) {
    if (!force && ayah == _top) return;
    _top = ayah;
    widget.onTop(ayah);
    _updateFraction(ayah);
  }

  // -- the thumb -------------------------------------------------------------

  /// For the Page unit and the whole Quran the thumb goes by page over the whole
  /// book; for the others it goes over the unit the top ayah is in.
  bool _scrubsByBook(WordsUnit unit) =>
      unit == WordsUnit.page || unit == WordsUnit.quran;

  Future<void> _updateFraction(AyahRef ayah) async {
    final generation = _generation;
    final unit = _model?.unit ?? widget.unit;
    final locator = ref.read(pageLocatorProvider);
    double? value;
    try {
      if (_scrubsByBook(unit)) {
        final page = await locator.pageOf(ayah);
        value = page == null
            ? ayah.index / (QuranDivisions.ayahCount - 1)
            : (page - 1) / (ChTable.totalPages - 1);
      } else {
        final chunk = await WordsStream.containing(unit, ayah, locator);
        if (chunk != null) {
          final length = chunk.range.length;
          value = length <= 1
              ? 0.0
              : (ayah.index - chunk.range.first.index) / (length - 1);
        }
      }
    } catch (_) {
      value = null;
    }
    if (mounted && generation == _generation && _top == ayah) {
      _fraction.value = value?.clamp(0.0, 1.0).toDouble();
    }
  }

  Future<AyahRef?> _targetOf(double fraction) async {
    final top = _top;
    if (top == null) return null;
    final locator = ref.read(pageLocatorProvider);
    final unit = _model?.unit ?? widget.unit;
    if (_scrubsByBook(unit)) {
      final page = 1 + (fraction * (ChTable.totalPages - 1)).round();
      return await WordsStream.firstStartingOn(page, locator) ??
          QuranDivisions.fromIndex(
            (fraction * (QuranDivisions.ayahCount - 1)).round(),
          );
    }
    final chunk = await WordsStream.containing(unit, top, locator);
    if (chunk == null) return null;
    return QuranDivisions.fromIndex(
      chunk.range.first.index + (fraction * (chunk.range.length - 1)).round(),
    );
  }

  /// `p 43 · Ruku 5`: where the thumb would land.
  Future<String> _bubbleFor(double fraction) async {
    try {
      final target = await _targetOf(fraction);
      if (target == null) return '';
      final page = await ref.read(pageLocatorProvider).pageOf(target);
      final ruku = QuranDivisions.rukuOf(target).number;
      return [if (page != null) 'p $page', 'Ruku $ruku'].join(' · ');
    } catch (_) {
      return '';
    }
  }

  Future<void> _scrubEnd(double fraction) async {
    _fraction.value = fraction;
    final target = await _targetOf(fraction);
    if (target != null && mounted) _open(target);
  }

  // -- building --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // A new translation or text size makes a new stream (see the class doc).
    ref.listen(selectedTranslationIdProvider, (previous, next) {
      if (_model != null && next.hasValue && next.value != _translationId) {
        _reopen();
      }
    });
    ref.listen(textSizeProvider, (previous, next) {
      if (_model != null && QuranTextSize.factor(next) != _scale) _reopen();
    });

    if (_missing) return QuranNotice(message: l10n.wordsNotInstalled);
    if (_problem != null) return QuranNotice(message: l10n.mushafBroken);
    final model = _model;
    if (model == null) return const SizedBox.shrink();

    final font = ref.watch(mushafTextFontProvider).value;
    final tafsirOn = ref.watch(
      tafsirSourcesProvider.select((v) => v.value?.isNotEmpty ?? false),
    );

    Widget row(StreamItem item) => switch (item) {
      BannerItem(:final banner) => StreamBanner(
        banner: banner,
        fontFamily: font,
        scale: _scale,
        onOpenInfo: widget.onOpenInfo,
      ),
      final AyahItem ayahItem => _AyahRow(
        item: ayahItem,
        translationId: _translationId,
        scale: _scale,
        fontFamily: font,
        tafsirOn: tafsirOn,
        highlighted: _highlight == ayahItem.at,
        onTafsir: widget.onTafsir,
      ),
      EdgeItem(:final kind) => switch (kind) {
        EdgeKind.startOfQuran => StreamEdge(title: l10n.readerStartOfQuran),
        EdgeKind.endOfQuran => StreamEdge(
          title: l10n.readerEndOfQuran,
          actionLabel: l10n.readerBackToStart,
          onAction: () => _open(const AyahRef(1, 1)),
        ),
        EdgeKind.keepReadingForward => StreamEdge(
          actionLabel: l10n.readerKeepReading,
          onAction: () => _release(forward: true),
        ),
        EdgeKind.keepReadingBack => StreamEdge(
          actionLabel: l10n.readerKeepReading,
          onAction: () => _release(forward: false),
        ),
      },
    };

    Widget buildAt(List<StreamItem> list, int index, {required bool forward}) {
      if (index >= list.length) {
        // The end of what is made: the next step is on its way. The empty room
        // is never a wall, the scroll goes on into it.
        _extend(forward: forward);
        return const SizedBox(height: 240);
      }
      if (index >= list.length - _prefetch) _extend(forward: forward);
      final r = row(list[index]);
      return r;
    }

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: CustomScrollView(
            key: ValueKey(_shown),
            controller: _scroll,
            center: _forwardKey,
            scrollCacheExtent: const ScrollCacheExtent.viewport(1.2),
            slivers: [
              SliverList(
                key: _backwardKey,
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      buildAt(model.backward, index, forward: false),
                  childCount:
                      model.backward.length + (model.backwardDone ? 0 : 1),
                  addAutomaticKeepAlives: false,
                ),
              ),
              SliverList(
                key: _forwardKey,
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      buildAt(model.forward, index, forward: true),
                  childCount:
                      model.forward.length + (model.forwardDone ? 0 : 1),
                  addAutomaticKeepAlives: false,
                ),
              ),
            ],
          ),
        ),
        PositionedDirectional(
          end: 0,
          top: AppSpacing.sm,
          bottom: AppSpacing.sm,
          width: _ScrubThumb.width,
          child: _ScrubThumb(
            fraction: _fraction,
            bubbleFor: _bubbleFor,
            onEnd: _scrubEnd,
          ),
        ),
      ],
    );
  }
}

/// One ayah row: the card of the ayah, with its words and translation read from
/// the per-surah data that the stream made ready before this row was built, so
/// the card has its full height from its first frame.
class _AyahRow extends ConsumerWidget {
  const _AyahRow({
    required this.item,
    required this.translationId,
    required this.scale,
    required this.fontFamily,
    required this.tafsirOn,
    required this.highlighted,
    required this.onTafsir,
  });

  final AyahItem item;
  final String? translationId;
  final double scale;
  final String? fontFamily;
  final bool tafsirOn;
  final bool highlighted;
  final void Function(AyahRef ayah) onTafsir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final at = item.at;
    final words = ref.watch(
      surahWordsProvider(at.surah).select((v) {
        final list = v.value;
        return list != null && at.ayah <= list.length ? list[at.ayah - 1] : null;
      }),
    );
    if (words == null) {
      // The data of the surah was let go and is being read again (a long way
      // back): a quiet room of about a card until it is there.
      return const SizedBox(height: 200);
    }
    final id = translationId;
    final translation = id == null
        ? null
        : ref.watch(
            surahTranslationProvider((surah: at.surah, id: id)).select(
              (v) => v.value?[at.key],
            ),
          );
    final l10n = context.l10n;
    String? tafsirLabel;
    if (tafsirOn) {
      final cover = ref.watch(tafsirCoverProvider(at)).value;
      tafsirLabel = cover == null || cover.length <= 1
          ? l10n.readerTafsir
          : l10n.readerTafsirCovers(ayahRangeText(cover));
    }
    return AyahCard(
      ayah: words,
      translation: translation,
      fontFamily: fontFamily,
      scale: scale,
      continuesOnPage: item.continuesOnPage,
      tafsirLabel: tafsirLabel,
      onTafsir: () => onTafsir(at),
      highlighted: highlighted,
    );
  }
}

/// The thumb on the screen edge. Dragging it shows a bubble (`p 43 · Ruku 5`)
/// and moves only the thumb; the stream is put on the place when the finger
/// lets go, so a drag never rebuilds the list for every move.
class _ScrubThumb extends StatefulWidget {
  const _ScrubThumb({
    required this.fraction,
    required this.bubbleFor,
    required this.onEnd,
  });

  /// The width of the strip that takes the drag.
  static const double width = 28;

  final ValueListenable<double?> fraction;
  final Future<String> Function(double fraction) bubbleFor;
  final void Function(double fraction) onEnd;

  @override
  State<_ScrubThumb> createState() => _ScrubThumbState();
}

class _ScrubThumbState extends State<_ScrubThumb> {
  static const double _thumbHeight = 44;

  double? _drag;
  String _bubble = '';
  int _request = 0;

  void _update(double dy, double height) {
    final usable = height - _thumbHeight;
    final f = usable <= 0
        ? 0.0
        : ((dy - _thumbHeight / 2) / usable).clamp(0.0, 1.0).toDouble();
    setState(() => _drag = f);
    final request = ++_request;
    widget.bubbleFor(f).then((text) {
      if (mounted && request == _request && _drag != null) {
        setState(() => _bubble = text);
      }
    });
  }

  void _finish() {
    final f = _drag;
    setState(() {
      _drag = null;
      _bubble = '';
    });
    _request++;
    if (f != null) widget.onEnd(f);
  }

  void _cancel() {
    setState(() {
      _drag = null;
      _bubble = '';
    });
    _request++;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        return ValueListenableBuilder<double?>(
          valueListenable: widget.fraction,
          builder: (context, value, _) {
            final f = _drag ?? value;
            if (f == null || height <= _thumbHeight) {
              return const SizedBox.shrink();
            }
            final top = f * (height - _thumbHeight);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onVerticalDragStart: (d) =>
                        _update(d.localPosition.dy, height),
                    onVerticalDragUpdate: (d) =>
                        _update(d.localPosition.dy, height),
                    onVerticalDragEnd: (_) => _finish(),
                    onVerticalDragCancel: _cancel,
                  ),
                ),
                PositionedDirectional(
                  end: 4,
                  top: top,
                  child: IgnorePointer(
                    child: Container(
                      width: 6,
                      height: _thumbHeight,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(
                          alpha: _drag == null ? 0.35 : 0.85,
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                if (_drag != null && _bubble.isNotEmpty)
                  PositionedDirectional(
                    end: _ScrubThumb.width + AppSpacing.xs,
                    top: top + (_thumbHeight - 28) / 2,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.inverseSurface,
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            _bubble,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: scheme.onInverseSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
