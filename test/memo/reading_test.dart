import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/memo/controller/reading_controller.dart';
import 'package:personaltskmng/memo/controller/reading_tracker.dart';
import 'package:personaltskmng/memo/data/reading_store.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/models/memo_settings.dart';
import 'package:personaltskmng/memo/models/page_map.dart';
import 'package:personaltskmng/memo/models/reading_log.dart';
import 'package:personaltskmng/memo/rules/reading_draft.dart';

final PageMap _map = PageMap.standard;
const Day _today = Day(20000);
int _id = 0;

MemoEvent _event(MemoKind kind, int day, int page) => MemoEvent(
  id: ++_id,
  day: Day(day),
  kind: kind,
  span: _map.spanOfPage(page),
);

ReadingLog _log(List<({int day, int page, int seconds})> reads) {
  var log = const ReadingLog();
  for (final r in reads) {
    log = log.add(
      day: r.day,
      page: r.page,
      span: _map.spanOfPage(r.page),
      seconds: r.seconds,
      visits: 1,
    );
  }
  return log;
}

List<DraftDay> _draft(ReadingLog log, List<MemoEvent> events) => ReadingDraft.build(
  log: log,
  events: events,
  settings: const MemoSettings(),
  today: _today,
);

void main() {
  group('ReadingDraft', () {
    test('long time on pages with nothing learned suggests Memorise, joined', () {
      final days = _draft(
        _log([
          (day: 20000, page: 100, seconds: 400),
          (day: 20000, page: 101, seconds: 400),
        ]),
        const [],
      );
      expect(days.length, 1);
      final item = days.single.items.single;
      expect(item.kind, MemoKind.m);
      expect([item.firstPage, item.lastPage], [100, 101]);
      expect(item.seconds, 800);
      expect(item.span, _map.spanOfPages(100, 101));
    });

    test('a short time on pages nothing is learned in is only reading', () {
      expect(_draft(_log([(day: 20000, page: 100, seconds: 100)]), const []), isEmpty);
    });

    test('a page that was learned yesterday suggests Review even for a short time', () {
      final days = _draft(
        _log([(day: 20000, page: 100, seconds: 90)]),
        [_event(MemoKind.m, 19999, 100)],
      );
      final item = days.single.items.single;
      expect(item.kind, MemoKind.r);
      expect(item.firstPage, 100);
    });

    test('under a minute and a half in a day is not counted by default', () {
      final events = [_event(MemoKind.m, 19999, 100)];
      expect(_draft(_log([(day: 20000, page: 100, seconds: 89)]), events), isEmpty);
      expect(_draft(_log([(day: 20000, page: 100, seconds: 90)]), events).length, 1);
    });

    test('a page passed through in a few seconds is not counted', () {
      expect(
        _draft(
          _log([(day: 20000, page: 100, seconds: 10)]),
          [_event(MemoKind.m, 19999, 100)],
        ),
        isEmpty,
      );
    });

    test('what the day\'s log already covers is not suggested again', () {
      // Memorised during the day: neither a Memorise nor a Review is suggested.
      expect(
        _draft(
          _log([(day: 20000, page: 100, seconds: 900)]),
          [_event(MemoKind.m, 20000, 100)],
        ),
        isEmpty,
      );
      // Reviewed during the day.
      expect(
        _draft(
          _log([(day: 20000, page: 100, seconds: 90)]),
          [_event(MemoKind.m, 19999, 100), _event(MemoKind.r, 20000, 100)],
        ),
        isEmpty,
      );
    });

    test('dismissed or confirmed pages do not come back', () {
      final base = _log([(day: 20000, page: 100, seconds: 900)]);
      final dismissed = base.dismiss(20000, [_map.spanOfPage(100).first]);
      expect(_draft(dismissed, const []), isEmpty);
      final restored = dismissed.undismiss(20000, [_map.spanOfPage(100).first]);
      expect(_draft(restored, const []).length, 1);
    });

    test('earlier days stay until dealt with, newest first', () {
      final days = _draft(
        _log([
          (day: 19998, page: 50, seconds: 600),
          (day: 19999, page: 60, seconds: 600),
        ]),
        const [],
      );
      expect(days.map((d) => d.day.epochDay), [19999, 19998]);
    });

    test('pages that do not follow each other are separate lines', () {
      final days = _draft(
        _log([
          (day: 20000, page: 100, seconds: 400),
          (day: 20000, page: 103, seconds: 400),
        ]),
        const [],
      );
      expect(days.single.items.length, 2);
    });

    test('the numbers are the user\'s', () {
      final strict = ReadingDraft.build(
        log: _log([(day: 20000, page: 100, seconds: 400)]),
        events: const [],
        settings: const MemoSettings(readMemoriseSeconds: 900),
        today: _today,
      );
      expect(strict, isEmpty);
    });
  });

  group('ReadingTracker', () {
    late DateTime now;
    late List<String> got;
    late ReadingTracker tracker;

    ReadingTracker make({bool enabled = true}) => ReadingTracker(
      enabled: enabled,
      idleCap: const Duration(seconds: 600),
      spanOf: _map.spanOfPage,
      clock: () => now,
      sink: (page, span, day, seconds, visits) => got.add('$page:$seconds:$visits'),
    );

    void wait(int seconds) => now = now.add(Duration(seconds: seconds));

    setUp(() {
      now = DateTime(2026, 11, 22, 10);
      got = [];
      tracker = make();
    });

    test('counts the time on a page and one visit', () {
      tracker.pageShown(5);
      wait(120);
      tracker.pageShown(6);
      wait(30);
      tracker.leave();
      expect(got, ['5:0:1', '5:120:0', '6:0:1', '6:30:0']);
    });

    test('showing the same page again is not a new visit', () {
      tracker.pageShown(5);
      wait(10);
      tracker.pageShown(5);
      wait(10);
      tracker.leave();
      expect(got, ['5:0:1', '5:20:0']);
    });

    test('time away (paused) is not counted', () {
      tracker.pageShown(5);
      wait(60);
      tracker.pause();
      wait(300);
      tracker.resume();
      wait(30);
      tracker.leave();
      expect(got, ['5:0:1', '5:60:0', '5:30:0']);
    });

    test('a phone left open stops counting after the idle cap', () {
      tracker.pageShown(5);
      wait(1000);
      tracker.leave();
      expect(got, ['5:0:1', '5:600:0']);
    });

    test('a touch keeps the page counting', () {
      tracker.pageShown(5);
      wait(500);
      tracker.interaction();
      wait(500);
      tracker.leave();
      expect(got, ['5:0:1', '5:1000:0']);
    });

    test('a touch after a long idle does not count the gap', () {
      tracker.pageShown(5);
      wait(1000);
      tracker.interaction();
      wait(100);
      tracker.leave();
      expect(got, ['5:0:1', '5:600:0', '5:100:0']);
    });

    test('flush reports so far and keeps counting', () {
      tracker.pageShown(5);
      wait(50);
      tracker.flush();
      wait(50);
      tracker.leave();
      expect(got, ['5:0:1', '5:50:0', '5:50:0']);
    });

    test('disabled measures nothing', () {
      final off = make(enabled: false);
      off.pageShown(5);
      wait(100);
      off.leave();
      expect(got, isEmpty);
    });
  });

  group('ReadingLog and ReadingController', () {
    test('time adds up per page and day, and survives a round trip', () {
      var log = const ReadingLog();
      final span = _map.spanOfPage(7);
      log = log.add(day: 5, page: 7, span: span, seconds: 30, visits: 1);
      log = log.add(day: 5, page: 7, span: span, seconds: 20, visits: 1);
      log = log.add(day: 6, page: 7, span: span, seconds: 10, visits: 1);
      expect(log.dwells.length, 2);
      expect(log.dwells.first.seconds, 50);
      expect(log.dwells.first.visits, 2);
      final back = ReadingLog.fromJson(log.dismiss(5, [span.first]).toJson());
      expect(back.dwells.length, 2);
      expect(back.isDismissed(5, span.first), isTrue);
    });

    test('old evidence is pruned', () {
      final span = _map.spanOfPage(7);
      final log = const ReadingLog()
          .add(day: 100, page: 7, span: span, seconds: 30, visits: 1)
          .add(day: 200, page: 7, span: span, seconds: 30, visits: 1);
      expect(log.pruned(200).dwells.map((d) => d.day), [200]);
    });

    test('the controller saves only when something is new', () async {
      final store = InMemoryReadingStore();
      final controller = ReadingController(store: store);
      await controller.load(_today);
      expect(await controller.persist(), isFalse);
      controller.record(day: _today, page: 7, span: _map.spanOfPage(7), seconds: 40, visits: 1);
      expect(await controller.persist(), isTrue);
      expect(await controller.persist(), isFalse);
      expect(store.saves, 1);
      final again = ReadingController(store: InMemoryReadingStore(store.text));
      await again.load(_today);
      expect(again.log.dwells.single.seconds, 40);
    });

    test('a failed save keeps the data for the next try', () async {
      final store = InMemoryReadingStore()..failOnSave = true;
      final controller = ReadingController(store: store);
      controller.record(day: _today, page: 7, span: _map.spanOfPage(7), seconds: 40, visits: 1);
      expect(await controller.persist(), isFalse);
      store.failOnSave = false;
      expect(await controller.persist(), isTrue);
    });

    test('erase forgets everything', () async {
      final controller = ReadingController(store: InMemoryReadingStore());
      controller.record(day: _today, page: 7, span: _map.spanOfPage(7), seconds: 40, visits: 1);
      await controller.erase();
      expect(controller.log.isEmpty, isTrue);
    });
  });

  test('reading settings survive a round trip and fall back when nonsense', () {
    const custom = MemoSettings(readMinSeconds: 60, readMemoriseSeconds: 600, readIdleSeconds: 300, trackReading: false);
    final back = MemoSettings.fromJson(custom.toJson());
    expect(back, custom);
    final broken = MemoSettings.fromJson({
      ...custom.toJson(),
      'readMemorise': 10, // below the minimum
    });
    expect(broken.readMemoriseSeconds, MemoSettings.defaultReadMemoriseSeconds);
    expect(broken.problem, isNull);
  });
}
