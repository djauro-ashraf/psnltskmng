import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/controller/memo_controller.dart';
import 'package:personaltskmng/memo/data/page_map_store.dart';
import 'package:personaltskmng/memo/models/memo_data.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/memo_view.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/partition.dart';
import 'package:personaltskmng/memo/models/planner_prefs.dart';
import 'package:personaltskmng/memo/models/span.dart';
import 'package:personaltskmng/mushaf/controller/mushaf_edition.dart';
import 'package:personaltskmng/mushaf/models/mushaf_edition.dart';
import 'package:personaltskmng/quran_data/controller/quran_providers.dart';
import 'package:personaltskmng/quran_data/models/page_locator.dart';

/// The memorisation controller (`memo.json`). Throws until it is overridden in
/// the composition root (app/dependencies.dart); tests override it with a
/// controller on an in-memory store.
final memoControllerProvider = Provider<MemoController>(
  (ref) => throw UnimplementedError('override in app/dependencies.dart'),
);

/// The clock the memorisation screens read. Tests override it.
final memoClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Where the page map of the second print is kept once it has been read.
final pageMapStoreProvider = Provider<PageMapStore>(
  (ref) => MemoryPageMapStore(),
);

/// Which ayahs are on which page, for the print the reader chose. The standard
/// print is bundled; for the other one the map is read from the downloaded
/// layout (once, then kept), and until then the standard map stands in for it
/// (`PageMap.exact` is false). Memorisation data never depends on it: only
/// page input and page display do.
class PageMapNotifier extends Notifier<PageMap> {
  @override
  PageMap build() {
    final edition = ref.watch(mushafEditionProvider);
    final locator = ref.watch(pageLocatorProvider);
    final store = ref.watch(pageMapStoreProvider);
    if (edition == MushafEdition.v1) return PageMap.standard;
    final cached = store.load(edition);
    if (cached != null) return cached;
    _read(edition, locator, store);
    return PageMap.standard.approximate();
  }

  Future<void> _read(
    MushafEdition edition,
    PageLocator locator,
    PageMapStore store,
  ) async {
    try {
      final firsts = <int>[];
      for (var page = 1; page <= PageMap.pageCount; page++) {
        final ayah = await locator.firstAyahOf(page);
        if (ayah == null) return;
        firsts.add(ayah.index);
      }
      final map = PageMap.fromFirstAyahs(firsts);
      if (map == null) return;
      try {
        await store.save(edition, map);
      } catch (_) {
        // Derived data: it is simply read again next time.
      }
      if (ref.mounted && ref.read(mushafEditionProvider) == edition) {
        state = map;
      }
    } catch (_) {
      // The layout is not there (yet): the standard map keeps standing in.
    }
  }
}

final pageMapProvider = NotifierProvider<PageMapNotifier, PageMap>(
  PageMapNotifier.new,
);

/// Everything the memorisation screens read: the data, the statuses as of
/// today, the pages and the partitions. Immutable; a new one is published
/// after every change.
final class MemoState {
  MemoState({
    required this.data,
    required this.today,
    required this.view,
    required this.pages,
    required this.partitions,
  });

  final MemoData data;
  final Day today;
  final MemoView view;
  final PageMap pages;

  /// The natural partitions followed by the user's own.
  final List<Partition> partitions;

  MemoSettings get settings => data.settings;
  PlannerPrefs get planner => data.planner;

  /// The user's own partitions.
  List<Partition> get custom => data.partitions;

  /// The partition [id] names; falls back to the user's first own partition.
  Partition partitionById(String id) {
    for (final p in partitions) {
      if (p.id == id) return p;
    }
    return custom.isNotEmpty ? custom.first : partitions.first;
  }

  /// The partition the overview and the planner open with.
  Partition get defaultPartition => partitionById(settings.partitionId);

  /// The log lines of [day], oldest first.
  List<MemoEvent> eventsOn(Day day) => [
    for (final e in data.events)
      if (e.day == day) e,
  ];
}

class MemoNotifier extends Notifier<MemoState> {
  MemoController get _controller => ref.read(memoControllerProvider);

  @override
  MemoState build() => _compose(ref.watch(pageMapProvider));

  MemoState _compose(PageMap pages) {
    final controller = _controller;
    final today = Day.fromDateTime(ref.read(memoClockProvider)());
    return MemoState(
      data: controller.data,
      today: today,
      view: controller.viewFor(today),
      pages: pages,
      partitions: controller.partitions(pages),
    );
  }

  void _publish() => state = _compose(ref.read(pageMapProvider));

  /// Reads the clock again (a new day has begun) and the data again.
  void refresh() => _publish();

  /// Logs [kind] on [span] on [day] (today when omitted).
  Future<LogResult> log({
    required MemoKind kind,
    required Span span,
    Day? day,
  }) async {
    final today = state.today;
    final result = await _controller.log(
      kind: kind,
      span: span,
      day: day ?? today,
      today: today,
    );
    _publish();
    return result;
  }

  /// Logs several lines at once on [day] (today when omitted): a confirmed
  /// draft. One group, so one undo.
  Future<BatchResult> logBatch({
    required List<({MemoKind kind, Span span})> items,
    Day? day,
  }) async {
    final today = state.today;
    final result = await _controller.logBatch(
      items: items,
      day: day ?? today,
      today: today,
    );
    _publish();
    return result;
  }

  Future<void> undo(int group) async {
    await _controller.deleteGroup(group);
    _publish();
  }

  Future<void> setSettings(MemoSettings settings) async {
    await _controller.setSettings(settings);
    _publish();
  }

  Future<void> setPlanner(PlannerPrefs prefs) async {
    await _controller.setPlanner(prefs);
    _publish();
  }

  Future<void> savePartition(Partition partition) async {
    await _controller.savePartition(partition);
    _publish();
  }

  Future<bool> deletePartition(String id) async {
    final removed = await _controller.deletePartition(id);
    _publish();
    return removed;
  }

  Future<void> replaceWith(MemoData data) async {
    await _controller.replaceWith(data);
    _publish();
  }
}

final memoProvider = NotifierProvider<MemoNotifier, MemoState>(
  MemoNotifier.new,
);

/// The day the user is logging for, or null for today (so it follows
/// midnight). Every way of logging reads it: the worklist, the piece sheet, the
/// typed log, the plan. Set from the calendar button on Today.
class LogDayNotifier extends Notifier<Day?> {
  @override
  Day? build() => null;

  void choose(Day? day) => state = day;
}

final logDayProvider = NotifierProvider<LogDayNotifier, Day?>(
  LogDayNotifier.new,
);
