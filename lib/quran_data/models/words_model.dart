import 'package:personaltskmng/domain/reference/quran_divisions.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';
import 'package:personaltskmng/quran_data/models/reading_banners.dart';
import 'package:personaltskmng/quran_data/models/unit_edges.dart';
import 'package:personaltskmng/quran_data/models/words_stream.dart';

/// One row of the Words stream.
sealed class StreamItem {
  const StreamItem();

  /// The ayah the row belongs to (the ayah a banner sits in front of); null for
  /// an edge card.
  AyahRef? get ayah;
}

/// The element in front of an ayah (a surah banner, a ruku hairline, a `p 43`
/// divider...).
final class BannerItem extends StreamItem {
  const BannerItem(this.banner);

  final ReadingBanner banner;

  @override
  AyahRef get ayah => banner.at;
}

/// One ayah card.
final class AyahItem extends StreamItem {
  const AyahItem(this.at, {this.continuesOnPage});

  final AyahRef at;

  /// The ayah goes on over this page: the card says "continues on p 44".
  final int? continuesOnPage;

  @override
  AyahRef get ayah => at;
}

/// What can be at the very end of the stream.
enum EdgeKind {
  /// Before 1:1: "Start of the Quran".
  startOfQuran,

  /// After 114:6: "End of the Quran" with "Back to the start".
  endOfQuran,

  /// After the last ayah of a part or a range: "Keep reading".
  keepReadingForward,

  /// Before the first ayah of a part or a range: "Keep reading" (backwards).
  keepReadingBack,

  /// At the end of a unit in Gate or Locked mode.
  unitEndForward,

  /// Before the start of a unit in Gate or Locked mode.
  unitStartBack,
}

final class EdgeItem extends StreamItem {
  const EdgeItem(
    this.kind, {
    this.unitLabel,
    this.edgeMode,
  });

  final EdgeKind kind;

  /// Label of the next/previous unit (e.g. "Juz 4", "Ruku 35").
  final String? unitLabel;

  /// Mode (gate or locked) that placed this tile.
  final UnitEdge? edgeMode;

  @override
  AyahRef? get ayah => null;
}

/// The rows of the Words stream, made as far as they are needed.
///
/// The stream is bidirectional around a first ayah (the "center"): [forward]
/// runs from it down, [backward] from it up (its first row is the one just above
/// the center). Both are made in small steps by [extendForward] and
/// [extendBackward], which the screen calls when the reader gets near an end,
/// so that the rows are there before they scroll into view and no seam, spinner
/// or jump shows when a unit ends: the next one is just more rows.
///
/// A row is cheap (an ayah key and a few flags): the words and the translation
/// are not in it, they are read per surah by the cards. [ready] is asked before
/// the rows of a surah are made, so the data of the cards is in memory when they
/// are built (no card changes its height after it was laid out).
///
/// The unit only decides which banners show up (the start of a ruku, a hizb, a
/// ch, a page...) and where they are upgraded; the stream does not stop at the
/// end of a unit. It stops at the ends of the Quran, and, when [stop] is given
/// (a part, a range), at its ends until [releaseForward] / [releaseBackward].
///
/// Pure Dart (the layout and the data are reached through the arguments).
final class WordsModel {
  WordsModel({
    required this.unit,
    required this.locator,
    required this.ready,
    this.stop,
    this.edgeMode = UnitEdge.flow,
  });

  final WordsUnit unit;
  final PageLocator locator;

  /// Makes the data of a surah available (its words, and the translation when
  /// one is chosen). Called before the rows of that surah are made.
  final Future<void> Function(int surah) ready;

  /// The run of ayahs the stream does not go out of (until released); null: the
  /// whole Quran.
  AyahRange? stop;

  /// What happens at unit boundaries: Flow, Gate, or Locked.
  final UnitEdge edgeMode;

  final List<StreamItem> forward = [];
  final List<StreamItem> backward = [];

  bool forwardDone = false;
  bool backwardDone = false;

  /// The unit was asked for something the layout cannot give (not downloaded).
  bool layoutMissing = false;

  WordsChunk? _forwardChunk;
  WordsChunk? _backwardChunk;
  AyahRef? _forwardNext;
  AyahRef? _backwardNext;

  // The active unit boundaries (fences) in Gate or Locked mode.
  AyahRange? _forwardFence;
  AyahRange? _backwardFence;

  // Where a released stop or fence goes on from.
  AyahRef? _heldForward;
  AyahRef? _heldBackward;

  Future<void>? _forwardBusy;
  Future<void>? _backwardBusy;

  /// Sets the stream on [anchor]: the first row of [forward] is the banner of
  /// [anchor] (when something starts there) and then its card. Returns false
  /// when the unit needs the layout and it is not downloaded.
  Future<bool> start(AyahRef anchor) async {
    // A stop is meant for the run it was made for: opening the stream outside
    // of it (the reader jumped out) does not stop at it.
    if (stop != null && !stop!.contains(anchor)) stop = null;
    final chunk = await WordsStream.containing(unit, anchor, locator);
    if (chunk == null) {
      layoutMissing = true;
      return false;
    }
    _forwardChunk = chunk;
    _backwardChunk = chunk;
    _forwardFence = chunk.range;
    _backwardFence = chunk.range;
    _forwardNext = anchor;
    final previous = QuranDivisions.previous(anchor);
    _backwardNext = previous;
    if (previous == null) {
      backward.add(const EdgeItem(EdgeKind.startOfQuran));
      backwardDone = true;
    } else if (_beforeStop(previous)) {
      backward.add(const EdgeItem(EdgeKind.keepReadingBack));
      _heldBackward = previous;
      backwardDone = true;
    } else if (_beforeFence(previous)) {
      final prevChunk = await WordsStream.containing(unit, previous, locator);
      final label = prevChunk != null ? _unitLabel(prevChunk) : null;
      backward.add(
        EdgeItem(
          EdgeKind.unitStartBack,
          unitLabel: label,
          edgeMode: edgeMode,
        ),
      );
      _heldBackward = previous;
      backwardDone = true;
    }
    return true;
  }

  bool _beforeStop(AyahRef ayah) => stop != null && ayah < stop!.first;
  bool _afterStop(AyahRef ayah) => stop != null && ayah > stop!.last;

  bool _beforeFence(AyahRef ayah) =>
      edgeMode != UnitEdge.flow &&
      unit != WordsUnit.quran &&
      _backwardFence != null &&
      ayah < _backwardFence!.first;

  bool _afterFence(AyahRef ayah) =>
      edgeMode != UnitEdge.flow &&
      unit != WordsUnit.quran &&
      _forwardFence != null &&
      ayah > _forwardFence!.last;

  String _unitLabel(WordsChunk chunk) => switch (chunk.unit) {
        WordsUnit.page => 'p ${chunk.number}',
        WordsUnit.ruku => 'Ruku ${chunk.number}',
        WordsUnit.hizb => 'Hizb ${chunk.number}',
        WordsUnit.juz => 'Juz ${chunk.number}',
        WordsUnit.surah => 'Surah ${chunk.number}',
        WordsUnit.ch => 'Ch ${chunk.number}',
        WordsUnit.quran => 'Quran',
      };

  /// Makes about [count] more ayahs below the last row. Only one runs at a
  /// time; a second call gets the one that is running.
  Future<void> extendForward([int count = 24]) =>
      _forwardBusy ??= _extendForward(count).whenComplete(() {
        _forwardBusy = null;
      });

  Future<void> _extendForward(int count) async {
    var made = 0;
    // One `ready` per surah per step (not per ayah): it listens, reads and lets
    // go, and a step crosses at most a few surahs.
    int? readied;
    while (made < count && !forwardDone) {
      final a = _forwardNext;
      var chunk = _forwardChunk;
      if (a == null || chunk == null) break;
      if (a > chunk.range.last) {
        chunk = await WordsStream.containing(unit, a, locator);
        if (chunk == null) {
          layoutMissing = true;
          forwardDone = true;
          break;
        }
        _forwardChunk = chunk;
      }
      if (readied != a.surah) {
        await ready(a.surah);
        readied = a.surah;
      }
      final unitStart = a == chunk.range.first ? chunk : null;
      final banner = ReadingBanners.at(a, unitStart: unitStart);
      if (banner != null) forward.add(BannerItem(banner));
      forward.add(
        AyahItem(
          a,
          continuesOnPage: a == chunk.range.last ? chunk.continuesOnPage : null,
        ),
      );
      made++;
      final next = QuranDivisions.next(a);
      _forwardNext = next;
      if (next == null) {
        forward.add(const EdgeItem(EdgeKind.endOfQuran));
        forwardDone = true;
      } else if (_afterStop(next)) {
        forward.add(const EdgeItem(EdgeKind.keepReadingForward));
        _heldForward = next;
        forwardDone = true;
      } else if (_afterFence(next)) {
        final nextChunk = await WordsStream.containing(unit, next, locator);
        final label = nextChunk != null ? _unitLabel(nextChunk) : null;
        forward.add(
          EdgeItem(
            EdgeKind.unitEndForward,
            unitLabel: label,
            edgeMode: edgeMode,
          ),
        );
        _heldForward = next;
        forwardDone = true;
      }
    }
  }

  /// Makes about [count] more ayahs above the last row of [backward].
  Future<void> extendBackward([int count = 24]) =>
      _backwardBusy ??= _extendBackward(count).whenComplete(() {
        _backwardBusy = null;
      });

  Future<void> _extendBackward(int count) async {
    var made = 0;
    int? readied;
    while (made < count && !backwardDone) {
      final a = _backwardNext;
      var chunk = _backwardChunk;
      if (a == null || chunk == null) break;
      if (a < chunk.range.first) {
        chunk = await WordsStream.containing(unit, a, locator);
        if (chunk == null) {
          layoutMissing = true;
          backwardDone = true;
          break;
        }
        _backwardChunk = chunk;
      }
      if (readied != a.surah) {
        await ready(a.surah);
        readied = a.surah;
      }
      // Upwards: the card first, the element in front of it above it.
      backward.add(
        AyahItem(
          a,
          continuesOnPage: a == chunk.range.last ? chunk.continuesOnPage : null,
        ),
      );
      final unitStart = a == chunk.range.first ? chunk : null;
      final banner = ReadingBanners.at(a, unitStart: unitStart);
      if (banner != null) backward.add(BannerItem(banner));
      made++;
      final previous = QuranDivisions.previous(a);
      _backwardNext = previous;
      if (previous == null) {
        backward.add(const EdgeItem(EdgeKind.startOfQuran));
        backwardDone = true;
      } else if (_beforeStop(previous)) {
        backward.add(const EdgeItem(EdgeKind.keepReadingBack));
        _heldBackward = previous;
        backwardDone = true;
      } else if (_beforeFence(previous)) {
        final prevChunk = await WordsStream.containing(unit, previous, locator);
        final label = prevChunk != null ? _unitLabel(prevChunk) : null;
        backward.add(
          EdgeItem(
            EdgeKind.unitStartBack,
            unitLabel: label,
            edgeMode: edgeMode,
          ),
        );
        _heldBackward = previous;
        backwardDone = true;
      }
    }
  }

  /// Passes the unit edge tile forward, advancing the fence by one unit.
  Future<void> passForward() async {
    if (_heldForward == null) return;
    final nextAyah = _heldForward!;
    final nextChunk = await WordsStream.containing(unit, nextAyah, locator);
    if (nextChunk == null) return;
    forward.removeWhere(
      (item) => item is EdgeItem && item.kind == EdgeKind.unitEndForward,
    );
    forwardDone = false;
    _forwardFence = nextChunk.range;
    _heldForward = null;
  }

  /// Passes the unit edge tile backward, advancing the fence by one unit.
  Future<void> passBackward() async {
    if (_heldBackward == null) return;
    final prevAyah = _heldBackward!;
    final prevChunk = await WordsStream.containing(unit, prevAyah, locator);
    if (prevChunk == null) return;
    backward.removeWhere(
      (item) => item is EdgeItem && item.kind == EdgeKind.unitStartBack,
    );
    backwardDone = false;
    _backwardFence = prevChunk.range;
    _heldBackward = null;
  }

  /// The reader tapped "Keep reading" at the end: the stop is gone below, and
  /// the stream goes on where it stopped. The tile is replaced by the next rows
  /// (the ones above it do not move).
  void releaseForward() {
    if (_heldForward == null) return;
    forward.removeWhere(
      (item) => item is EdgeItem && item.kind == EdgeKind.keepReadingForward,
    );
    forwardDone = false;
    _heldForward = null;
    stop = stop == null ? null : _stopWithoutEnd();
  }

  /// The same for the tile above.
  void releaseBackward() {
    if (_heldBackward == null) return;
    backward.removeWhere(
      (item) => item is EdgeItem && item.kind == EdgeKind.keepReadingBack,
    );
    backwardDone = false;
    _heldBackward = null;
    stop = stop == null ? null : _stopWithoutStart();
  }

  // The stop keeps the end that was not released; a stop with no ends is null.
  AyahRange? _stopWithoutEnd() =>
      _heldBackward == null ? null : AyahRange(stop!.first, _lastAyah);
  AyahRange? _stopWithoutStart() =>
      _heldForward == null ? null : AyahRange(_firstAyah, stop!.last);

  static const AyahRef _firstAyah = AyahRef(1, 1);
  static const AyahRef _lastAyah = AyahRef(114, 6);
}
