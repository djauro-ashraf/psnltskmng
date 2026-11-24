import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/memo/controller/reading_controller.dart';
import 'package:personaltskmng/memo/controller/reading_tracker.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/reading_log.dart';
import 'package:personaltskmng/memo/rules/reading_draft.dart';

/// The reading evidence (`reading.json`). Throws until it is overridden in the
/// composition root (app/dependencies.dart); tests override it.
final readingControllerProvider = Provider<ReadingController>(
  (ref) => throw UnimplementedError('override in app/dependencies.dart'),
);

/// The reading evidence as the screens see it. The reader records into the
/// controller every few seconds without publishing; this publishes when the
/// reader saves (now and then, and when it closes).
class ReadingNotifier extends Notifier<ReadingLog> {
  ReadingController? get _controller {
    try {
      return ref.read(readingControllerProvider);
    } catch (_) {
      return null;
    }
  }

  @override
  ReadingLog build() => _controller?.log ?? const ReadingLog();

  /// Saves what was recorded and publishes it when there was something new.
  Future<void> persistAndRefresh() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      final wrote = await controller.persist();
      if (wrote && ref.mounted) state = controller.log;
    } catch (_) {}
  }

  /// Marks the pages of a draft line as done with.
  Future<void> dismiss(Day day, Iterable<int> firsts) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.dismiss(day, firsts);
    if (ref.mounted) state = controller.log;
  }

  /// Brings them back (an undo of a confirmation).
  Future<void> undismiss(Day day, Iterable<int> firsts) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.undismiss(day, firsts);
    if (ref.mounted) state = controller.log;
  }

  /// Forgets all reading evidence.
  Future<void> erase() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.erase();
    if (ref.mounted) state = controller.log;
  }
}

final readingProvider = NotifierProvider<ReadingNotifier, ReadingLog>(
  ReadingNotifier.new,
);

/// What the user changed on a suggested line during this visit to the screen:
/// the kind, or the pages. Never stored: a confirmed line is in the log, a
/// dismissed one is dismissed for good.
final class DraftEdit {
  const DraftEdit({this.kind, this.firstPage, this.lastPage});

  final MemoKind? kind;
  final int? firstPage;
  final int? lastPage;

  DraftEdit copyWith({MemoKind? kind, int? firstPage, int? lastPage}) => DraftEdit(
    kind: kind ?? this.kind,
    firstPage: firstPage ?? this.firstPage,
    lastPage: lastPage ?? this.lastPage,
  );
}

class DraftEditsNotifier extends Notifier<Map<String, DraftEdit>> {
  @override
  Map<String, DraftEdit> build() => const {};

  void change(String key, DraftEdit Function(DraftEdit? current) update) =>
      state = {...state, key: update(state[key])};
}

final draftEditsProvider =
    NotifierProvider<DraftEditsNotifier, Map<String, DraftEdit>>(
      DraftEditsNotifier.new,
    );

/// The suggested log, one entry per day with something to suggest (newest day
/// first), with the user's edits of this visit applied. Empty when reading
/// suggestions are off.
final readingDraftProvider = Provider<List<DraftDay>>((ref) {
  final memo = ref.watch(memoProvider);
  if (!memo.settings.trackReading) return const [];
  final log = ref.watch(readingProvider);
  final edits = ref.watch(draftEditsProvider);
  final base = ReadingDraft.build(
    log: log,
    events: memo.data.events,
    settings: memo.settings,
    today: memo.today,
  );
  return [
    for (final day in base)
      DraftDay(day.day, [
        for (final item in day.items) _applyEdit(item, edits[item.key], memo.pages),
      ]),
  ];
});

DraftItem _applyEdit(DraftItem item, DraftEdit? edit, PageMap pages) {
  if (edit == null) return item;
  final first = (edit.firstPage ?? item.firstPage).clamp(1, PageMap.pageCount);
  var last = (edit.lastPage ?? item.lastPage).clamp(1, PageMap.pageCount);
  if (last < first) last = first;
  return DraftItem(
    day: item.day,
    kind: edit.kind ?? item.kind,
    span: pages.spanOfPages(first, last),
    firstPage: first,
    lastPage: last,
    seconds: item.seconds,
    firsts: item.firsts,
    key: item.key,
  );
}

/// A tracker for one visit to the reader, wired to the evidence and to the
/// user's reading settings. Everything it needs is read now, so it still works
/// while the reader is being torn down. When reading suggestions are off it
/// measures nothing.
ReadingTracker createReadingTracker(WidgetRef ref) {
  try {
    final memo = ref.read(memoProvider);
    final controller = ref.read(readingControllerProvider);
    final pages = memo.pages;
    return ReadingTracker(
      enabled: memo.settings.trackReading,
      idleCap: Duration(seconds: memo.settings.readIdleSeconds),
      spanOf: pages.spanOfPage,
      sink: (page, span, day, seconds, visits) => controller.record(
        day: day,
        page: page,
        span: span,
        seconds: seconds,
        visits: visits,
      ),
    );
  } catch (_) {
    // No memorisation wiring (a build or a test without it): measure nothing.
    return ReadingTracker(
      enabled: false,
      idleCap: Duration.zero,
      spanOf: PageMap.standard.spanOfPage,
      sink: (page, span, day, seconds, visits) {},
    );
  }
}
