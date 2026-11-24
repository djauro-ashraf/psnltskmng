import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/span.dart';

/// One piece of a partition with how it stands.
final class SegmentStatus {
  const SegmentStatus(this.segment, this.status);

  final Segment segment;
  final SpanStatus status;

  /// How urgent the piece is, 0 most: 0 has forgotten ayahs, 1 has fading ayahs,
  /// 2 has something that will fall if it gets no review, 3 is the rest.
  int get rank {
    if (status.forgotten > 0) return 0;
    if (status.fading > 0) return 1;
    if (status.nextDeadline != null) return 2;
    return 3;
  }

  /// Days until something here falls a step (0 = today), or null.
  int? daysToFall(Day today) {
    final deadline = status.nextDeadline;
    return deadline == null ? null : deadline.epochDay - today.epochDay;
  }
}

/// What the Today screen asks of the statuses: which pieces need a review now,
/// and what to memorise next. Pure Dart; nothing here is stored or decided by
/// the app on the user's behalf: it only orders what the statuses say.
abstract final class Worklist {
  /// Every piece of [partition] with its status.
  static List<SegmentStatus> of(MemoView view, Partition partition) => [
    for (final segment in partition.segments)
      SegmentStatus(segment, view.statusOf(segment.span)),
  ];

  /// Most urgent first; ties go to the piece that falls sooner, then to the
  /// lower number.
  static int compareUrgency(SegmentStatus a, SegmentStatus b, Day today) {
    final byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    final da = a.daysToFall(today);
    final db = b.daysToFall(today);
    if (da != null && db != null && da != db) return da.compareTo(db);
    if (da == null && db != null) return 1;
    if (da != null && db == null) return -1;
    return a.segment.number.compareTo(b.segment.number);
  }

  /// The pieces that need a review: something is forgotten or fading, or
  /// something falls within [withinDays]. Only pieces with learned ayahs. Most
  /// urgent first, at most [limit].
  static List<SegmentStatus> attention(
    List<SegmentStatus> all,
    Day today, {
    required int withinDays,
    int limit = 12,
  }) {
    final picked = [
      for (final s in all)
        if (s.status.learned > 0 &&
            (s.status.forgotten > 0 ||
                s.status.fading > 0 ||
                ((s.daysToFall(today) ?? 1 << 30) <= withinDays)))
          s,
    ]..sort((a, b) => compareUrgency(a, b, today));
    return picked.length > limit ? picked.sublist(0, limit) : picked;
  }

  /// The piece to memorise next: the one holding the first ayah that can be
  /// memorised after the last ayah learned (so memorising moves forward), or,
  /// when nothing is left forward, the first one from the start. Null when
  /// everything is learned.
  static SegmentStatus? nextToMemorise(MemoView view, Partition partition) {
    var lastLearned = -1;
    for (var i = Span.quran.last; i >= 0; i--) {
      if (view.isLearned(i)) {
        lastLearned = i;
        break;
      }
    }
    final place =
        _firstToMemorise(view, lastLearned + 1, Span.quran.last) ??
        _firstToMemorise(view, 0, lastLearned);
    if (place == null) return null;
    final segment = partition.segment(partition.numberAt(place));
    return SegmentStatus(segment, view.statusOf(segment.span));
  }

  /// The place of the first ayah from [from] to [to] that memorise is taken on.
  static int? firstToMemorise(MemoView view, Span within) =>
      _firstToMemorise(view, within.first, within.last);

  static int? _firstToMemorise(MemoView view, int from, int to) {
    for (var i = from; i <= to; i++) {
      if (view.statusAt(i).acceptsMemorise) return i;
    }
    return null;
  }
}
