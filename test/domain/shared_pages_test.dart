import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/expansion_tracker.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_record.dart';
import 'package:personaltskmng/domain/models/page_state.dart';
import 'package:personaltskmng/domain/models/planner_constraints.dart';
import 'package:personaltskmng/domain/models/q.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/domain/reference/s_table.dart';
import 'package:personaltskmng/domain/reference/shared_pages.dart';
import 'package:personaltskmng/domain/rules/m_rules.dart';
import 'package:personaltskmng/domain/rules/rule_violation.dart';
import 'package:personaltskmng/domain/rules/rules_engine.dart';

void main() {
  const engine = RulesEngine(PlannerConstraints());
  const day0 = Day(0);
  const day1 = Day(1);

  group('STable.sOfPage / SharedPages', () {
    test('every page is in at least one s', () {
      for (var page = 1; page <= ChTable.totalPages; page++) {
        expect(STable.sOfPage(page), isNotEmpty, reason: 'page $page');
      }
    });

    test('an s that ends where the next starts shares that page', () {
      expect(STable.sOfPage(106), [4, 5]);
      expect(STable.sOfPage(105), [4]);
      expect(STable.sOfPage(107), [5]);
      expect(STable.sOfPage(1), [1]);
    });

    test('the last pages hold three s', () {
      expect(STable.sOfPage(604), [112, 113, 114]);
      expect(STable.sOfPage(596), [92, 93, 94]);
    });

    test('51 pages are in two or more s', () {
      expect(STable.sharedPages, hasLength(51));
      expect(STable.sharedPages, contains(106));
      expect(STable.sharedPages, contains(604));
    });

    test('a page outside the table is a RangeError', () {
      expect(() => STable.sOfPage(0), throwsRangeError);
      expect(() => STable.sOfPage(605), throwsRangeError);
    });

    test('every page shared by two ch is also shared by two s', () {
      // Then the shared pages are exactly the s-shared ones; if a table change
      // breaks this, SharedPages still covers both kinds.
      for (final page in ChTable.instance.sharedPages) {
        expect(STable.sOfPage(page).length, greaterThan(1), reason: 'p $page');
      }
      expect(SharedPages.all, STable.sharedPages);
    });

    test('isShared: page 106 and 604 yes, a page of one ch and one s no', () {
      expect(SharedPages.isShared(106), isTrue);
      expect(SharedPages.isShared(604), isTrue);
      expect(SharedPages.isShared(293), isTrue);
      expect(SharedPages.isShared(107), isFalse);
      expect(SharedPages.isShared(290), isFalse);
      expect(SharedPages.isShared(0), isFalse);
      expect(SharedPages.isShared(605), isFalse);
    });

    test('nothing is shared in a Q the tables do not describe', () {
      final small = engine.createQ(
        id: 's',
        totalPages: 10,
        initialMainD: const PageRange(1, 5),
        today: day0,
      );
      expect(SharedPages.covers(small), isFalse);
      expect(SharedPages.isSharedIn(small, 4), isFalse);
    });
  });

  group('RulesEngine.applyR - a shared page logged through two units', () {
    // Main D range 282-322, every page D1, M'd on day 0. ch 30 is p 282-293,
    // ch 31 is p 293-304: p 293 is in both ch (and in s 17 and s 18).
    Q freshQ() => engine.createQ(
      id: 'q',
      totalPages: 604,
      initialMainD: const PageRange(282, 322),
      today: day0,
    );

    Q r(Q q, int from, int to, {bool successful = true}) {
      final out = engine.applyR(
        q: q,
        range: PageRange(from, to),
        today: day1,
        successful: successful,
      );
      expect(out.violationOrNull, isNull, reason: 'R $from-$to');
      return out.valueOrNull!;
    }

    test('ch 30 then ch 31 as displayed: both accepted, p 293 earns ONE unit', () {
      var q = r(freshQ(), 282, 293);
      expect(q.page(293).progressUnits, 1);
      final operationsBefore = q.operations.length;

      q = r(q, 293, 304);

      expect(q.page(293).progressUnits, 1, reason: 'no second unit');
      expect(q.page(293).rCount, 1);
      expect(q.page(293).lastR, day1);
      for (var n = 294; n <= 304; n++) {
        expect(q.page(n).progressUnits, 1, reason: 'p $n');
      }
      expect(q.operations, hasLength(operationsBefore + 1));
      expect(q.operations.last.range, const PageRange(293, 304));
      expect(q.checkInvariants(), isEmpty);
    });

    test('ch 31 then ch 30: the order does not matter', () {
      var q = r(freshQ(), 293, 304);
      q = r(q, 282, 293);
      expect(q.page(293).progressUnits, 1);
      expect(q.page(293).rCount, 1);
      expect(q.page(282).progressUnits, 1);
      expect(q.page(304).progressUnits, 1);
    });

    test('two s that meet on p 293: s 17 (282-293) then s 18 (293-304)', () {
      var q = r(freshQ(), STable.firstPageOf(17), STable.lastPageOf(17));
      q = r(q, STable.firstPageOf(18), STable.lastPageOf(18));
      expect(q.page(293).progressUnits, 1);
      expect(q.page(304).progressUnits, 1);
    });

    test('the shared page alone, again and again, changes nothing', () {
      var q = r(freshQ(), 293, 293);
      final once = q.page(293);
      q = r(q, 293, 293);
      q = r(q, 293, 293);
      expect(q.page(293).progressUnits, once.progressUnits);
      expect(q.page(293).rCount, once.rCount);
      expect(q.page(293).lastR, once.lastR);
    });

    test('p 604 is in three s: s 112, 113 and 114 are three logs, one unit', () {
      var q = engine.createQ(
        id: 'q',
        totalPages: 604,
        initialMainD: const PageRange(596, 604),
        today: day0,
      );
      for (final s in [112, 113, 114]) {
        q = r(q, STable.firstPageOf(s), STable.lastPageOf(s));
      }
      expect(q.page(604).progressUnits, 1);
      expect(q.page(604).rCount, 1);
    });

    test('a non-shared page is still refused a second time, and it is the one named', () {
      final q = r(freshQ(), 282, 293);
      // 290 is in one ch and one s: refused, even though 293 alone would pass.
      final again = engine.applyR(
        q: q,
        range: const PageRange(290, 300),
        today: day1,
        successful: true,
      );
      expect(again.violationOrNull?.reason, RuleViolationReason.pageAlreadyRToday);
      expect(again.violationOrNull?.page, 290);
      expect(q.page(290).progressUnits, 1);
    });

    test('a repeat on the shared page plus new pages after it is accepted', () {
      final q = r(freshQ(), 282, 293);
      final next = r(q, 293, 296);
      expect(next.page(293).progressUnits, 1);
      expect(next.page(296).progressUnits, 1);
      expect(next.page(297).progressUnits, 0);
    });

    test('a shared page that had no R yet earns its unit through either log', () {
      final q = r(freshQ(), 294, 304); // ch 31 without its first page
      expect(q.page(293).progressUnits, 0);
      final next = r(q, 282, 293);
      expect(next.page(293).progressUnits, 1);
      expect(next.page(293).rCount, 1);
    });

    test('an unsuccessful R on the shared page is still accepted and changes nothing', () {
      var q = r(freshQ(), 282, 293);
      q = r(q, 293, 304, successful: false);
      expect(q.page(293).progressUnits, 1);
      expect(q.page(300).progressUnits, 0, reason: 'unsuccessful: nothing earned');
    });

    test('L then R on a shared page: the R is a repeat, the marker stays', () {
      var q = engine
          .applyL(
            q: freshQ(),
            range: const PageRange(282, 293),
            today: day1,
            successful: true,
          )
          .valueOrNull!;
      q = r(q, 293, 304);
      expect(q.page(293).progressUnits, 1);
      expect(q.page(293).lastL, day1);
      expect(q.page(294).progressUnits, 1);
      expect(q.page(294).lastL, isNull);
    });

    test('the next day the page can earn again', () {
      var q = r(freshQ(), 282, 293);
      q = r(q, 293, 304);
      final tomorrow = engine.applyR(
        q: q,
        range: const PageRange(282, 293),
        today: const Day(2),
        successful: true,
      );
      expect(tomorrow.violationOrNull, isNull);
      expect(tomorrow.valueOrNull!.page(293).progressUnits, 2);
    });
  });

  group('RulesEngine.applyR - shared page and merged ch', () {
    // ch 30 (owns 282-293) and ch 31 (owns 294-304) both merged, D2, with
    // identical records inside each: one unit each. p 293 is shown in both.
    Q mergedQ() {
      final base = engine.createQ(
        id: 'q',
        totalPages: 604,
        initialMainD: const PageRange(282, 322),
        today: day0,
      );
      final pages = [...base.pages];
      for (var n = 282; n <= 304; n++) {
        final p = base.page(n);
        pages[n - 1] = PageRecord(
          number: n,
          state: PageState.d2,
          lastM: p.lastM,
          lastR: p.lastR,
          mCount: p.mCount,
          rCount: p.rCount,
          stateSince: p.stateSince,
          clockStart: p.clockStart,
          dEntries: p.dEntries,
        );
      }
      return base.copyWith(pages: pages, mergedCh: const {30, 31});
    }

    test('ch 31 as displayed (293-304) after ch 30 whole is accepted', () {
      final start = mergedQ();
      expect(start.checkInvariants(), isEmpty);
      final first = engine.applyR(
        q: start,
        range: const PageRange(282, 293),
        today: day1,
        successful: true,
      );
      expect(first.violationOrNull, isNull);
      final second = engine.applyR(
        q: first.valueOrNull!,
        range: const PageRange(293, 304),
        today: day1,
        successful: true,
      );
      expect(second.violationOrNull, isNull);
      final q = second.valueOrNull!;
      expect(q.page(293).progressUnits, 1);
      expect(q.page(300).progressUnits, 1);
      expect(q.checkInvariants(), isEmpty);
    });

    test('without ch 30 done first, 293-304 is accepted and p293 is left as it is', () {
      // p293 is ch 30's last owned page (merged) and ch 31's first as displayed.
      // The user is going through ch 31, so the log is accepted; p293 cannot
      // earn alone (ch 30 keeps identical records), the rest is applied.
      final start = mergedQ();
      final out = engine.applyR(
        q: start,
        range: const PageRange(293, 304),
        today: day1,
        successful: true,
      );
      expect(out.violationOrNull, isNull);
      final q = out.valueOrNull!;
      expect(q.page(293).progressUnits, 0);
      expect(q.page(293).lastR, start.page(293).lastR);
      expect(q.page(293).rCount, start.page(293).rCount);
      expect(q.page(293).progressUnits, q.page(282).progressUnits);
      expect(q.page(294).progressUnits, 1);
      expect(q.page(304).progressUnits, 1);
      expect(q.checkInvariants(), isEmpty);
      expect(q.operations.last.range.start, 293);
      expect(q.operations.last.range.end, 304);
    });

    test('p293 alone is accepted, recorded and changes nothing', () {
      final start = mergedQ();
      final out = engine.applyR(
        q: start,
        range: const PageRange(293, 293),
        today: day1,
        successful: true,
      );
      expect(out.violationOrNull, isNull);
      final q = out.valueOrNull!;
      expect(q.page(293).progressUnits, 0);
      expect(q.page(293).lastR, start.page(293).lastR);
      expect(q.page(293).rCount, start.page(293).rCount);
      expect(q.page(294).progressUnits, 0);
      expect(q.checkInvariants(), isEmpty);
      expect(q.operations.length, start.operations.length + 1);
      expect(q.operations.last.range.start, 293);
      expect(q.operations.last.range.end, 293);
    });

    test('ch 30 whole the same day after that still credits p293', () {
      final first = engine
          .applyR(
            q: mergedQ(),
            range: const PageRange(293, 304),
            today: day1,
            successful: true,
          )
          .valueOrNull!;
      final second = engine.applyR(
        q: first,
        range: const PageRange(282, 293),
        today: day1,
        successful: true,
      );
      expect(second.violationOrNull, isNull);
      final q = second.valueOrNull!;
      // p293 earned its unit now, with the rest of ch 30: identical again.
      for (var n = 282; n <= 293; n++) {
        expect(q.page(n).progressUnits, 1, reason: 'page $n');
      }
      expect(q.checkInvariants(), isEmpty);
    });

    test('a range that starts earlier inside ch 30 is still a partial R', () {
      for (final range in const [PageRange(290, 304), PageRange(290, 293)]) {
        final out = engine.applyR(
          q: mergedQ(),
          range: range,
          today: day1,
          successful: true,
        );
        expect(
          out.violationOrNull?.reason,
          RuleViolationReason.mergedChPartial,
          reason: '${range.start}-${range.end}',
        );
        expect(out.violationOrNull?.ch, 30);
      }
    });

    test('a page of a merged ch that is not its shared last page is still partial', () {
      final out = engine.applyR(
        q: mergedQ(),
        range: const PageRange(282, 282),
        today: day1,
        successful: true,
      );
      expect(out.violationOrNull?.reason, RuleViolationReason.mergedChPartial);
      expect(out.violationOrNull?.ch, 30);
    });

    test('L on 293-304 leaves p293 without a marker and marks ch 31', () {
      final out = engine.applyL(
        q: mergedQ(),
        range: const PageRange(293, 304),
        today: day1,
        successful: true,
      );
      expect(out.violationOrNull, isNull);
      final q = out.valueOrNull!;
      expect(q.page(293).lastL, isNull);
      expect(q.page(293).progressUnits, 0);
      expect(q.page(294).lastL?.epochDay, day1.epochDay);
      expect(q.page(304).lastL?.epochDay, day1.epochDay);
      expect(q.page(294).progressUnits, 1);
      expect(q.checkInvariants(), isEmpty);
    });

    test('a non-shared page of a merged ch is still one R per day', () {
      final q = engine
          .applyR(
            q: mergedQ(),
            range: const PageRange(282, 293),
            today: day1,
            successful: true,
          )
          .valueOrNull!;
      final again = engine.applyR(
        q: q,
        range: const PageRange(282, 293),
        today: day1,
        successful: true,
      );
      // 282 comes first and is not shared: that page is the one named.
      expect(again.violationOrNull?.reason, RuleViolationReason.pageAlreadyRToday);
      expect(again.violationOrNull?.page, 282);
    });
  });

  group('MRules - the repeat M of a shared page', () {
    const entered = PageRecord(
      number: 106,
      state: PageState.d1,
      mCount: 1,
      dEntries: 1,
    );

    test('only a shared page past its entry, with its repeat unused, can repeat', () {
      expect(MRules.canRepeat(entered, shared: true), isTrue);
      expect(MRules.canRepeat(entered, shared: false), isFalse);
      expect(MRules.canRepeat(entered.copyWith(mRepeated: true), shared: true), isFalse);
      for (final state in [PageState.d2, PageState.d3, PageState.c, PageState.f1, PageState.f2]) {
        expect(MRules.canRepeat(entered.copyWith(state: state), shared: true), isTrue, reason: state.name);
      }
    });

    test('ND and F3 take a normal M, never a repeat', () {
      expect(MRules.canRepeat(const PageRecord(number: 106), shared: true), isFalse);
      expect(MRules.canRepeat(entered.copyWith(state: PageState.f3), shared: true), isFalse);
    });

    test('the repeat sets the marker and changes nothing else', () {
      final repeated = MRules.applyRepeat(entered.copyWith(lastM: day0, progressUnits: 2));
      expect(repeated.mRepeated, isTrue);
      expect(repeated.state, PageState.d1);
      expect(repeated.mCount, 1);
      expect(repeated.dEntries, 1);
      expect(repeated.lastM, day0);
      expect(repeated.progressUnits, 2);
    });

    test('an entry M opens a new pair: it clears the marker', () {
      final forgotten = entered.copyWith(state: PageState.nd, mRepeated: true);
      final again = MRules.apply(forgotten, day1);
      expect(again.state, PageState.d1);
      expect(again.mRepeated, isFalse);
      expect(again.mCount, 2);
    });
  });

  group('RulesEngine.applyM - a shared page learned through two units', () {
    // Main D range 50-76, every page D1, M'd on day 0. s 4 is p 77-106 and s 5 is
    // p 106-127: p 106 is in both, so learning s 4 and then s 5 M's p 106 twice.
    Q freshQ() => engine.createQ(
      id: 'q',
      totalPages: 604,
      initialMainD: const PageRange(50, 76),
      today: day0,
    );

    Q m(Q q, int from, int to, {Day today = day0}) {
      final out = engine.applyM(q: q, range: PageRange(from, to), today: today);
      expect(out.violationOrNull, isNull, reason: 'M $from-$to');
      return out.valueOrNull!;
    }

    test('s 4 then s 5 on a later day: p 106 is accepted a second time and left as it is', () {
      var q = m(freshQ(), 77, 106);
      expect(q.page(106).mCount, 1);
      expect(q.page(106).mRepeated, isFalse);
      final operationsBefore = q.operations.length;

      q = m(q, 106, 127, today: day1);

      final p = q.page(106);
      expect(p.state, PageState.d1);
      expect(p.mCount, 1, reason: 'not a second entry');
      expect(p.dEntries, 1);
      expect(p.lastM, day0, reason: 'the repeat does not move the last M');
      expect(p.progressUnits, 0);
      expect(p.mRepeated, isTrue);
      for (var n = 107; n <= 127; n++) {
        expect(q.page(n).state, PageState.d1, reason: 'p $n');
        expect(q.page(n).mCount, 1, reason: 'p $n');
        expect(q.page(n).lastM, day1, reason: 'p $n');
      }
      expect(q.operations, hasLength(operationsBefore + 1));
      expect(q.operations.last.range, const PageRange(106, 127));
      expect(q.checkInvariants(), isEmpty);
    });

    test('the same day works too, and the expansion counts the entered pages only', () {
      var q = m(freshQ(), 77, 106);
      q = m(q, 106, 127);

      expect(q.page(106).mRepeated, isTrue);
      expect(q.expansion.consecutive, 2);
      expect(q.expansion.lastDirection, ExpansionDirection.forward);
      expect(q.expansion.events.last.range, const PageRange(107, 127));
    });

    test('the shared page alone: accepted, logged, and no expansion', () {
      var q = m(freshQ(), 77, 106);
      final consecutive = q.expansion.consecutive;
      final operationsBefore = q.operations.length;

      q = m(q, 106, 106, today: day1);

      expect(q.page(106).mRepeated, isTrue);
      expect(q.operations, hasLength(operationsBefore + 1));
      expect(q.expansion.consecutive, consecutive);
      expect(q.expansion.events.length, 1);
    });

    test('a third M on the page is refused, alone or inside a range', () {
      var q = m(freshQ(), 77, 106);
      q = m(q, 106, 127, today: day1);

      for (final range in [const PageRange(106, 106), const PageRange(106, 130)]) {
        final again = engine.applyM(q: q, range: range, today: day1);
        expect(again.violationOrNull?.reason, RuleViolationReason.pageNotEligibleForM, reason: '$range');
        expect(again.violationOrNull?.page, 106);
      }
    });

    test('a page that is not shared never repeats, and it is the one named', () {
      final q = m(freshQ(), 77, 106);

      final alone = engine.applyM(q: q, range: const PageRange(100, 100), today: day1);
      expect(alone.violationOrNull?.reason, RuleViolationReason.pageNotEligibleForM);
      expect(alone.violationOrNull?.page, 100);

      // p 106 could repeat, p 105 cannot: the range is refused as a whole.
      final mixed = engine.applyM(q: q, range: const PageRange(105, 106), today: day1);
      expect(mixed.violationOrNull?.page, 105);
      expect(q.page(106).mRepeated, isFalse, reason: 'a refused M changes nothing');
    });

    test('the repeat does not depend on the level the page has reached', () {
      var q = m(freshQ(), 77, 106);
      final pages = [...q.pages];
      pages[105] = pages[105].copyWith(state: PageState.d2);
      q = q.copyWith(pages: pages);

      final out = engine.applyM(q: q, range: const PageRange(106, 106), today: day1);

      expect(out.violationOrNull, isNull);
      expect(out.valueOrNull!.page(106).state, PageState.d2);
      expect(out.valueOrNull!.page(106).mRepeated, isTrue);
    });

    test('once forgotten the page is M-eligible again, then gets its pair again', () {
      var q = m(freshQ(), 77, 106);
      q = m(q, 106, 127, today: day1);
      expect(q.page(106).mRepeated, isTrue);

      // A year with no R: every page is forgotten (ND), p 106 with its old marker.
      const later = Day(400);
      q = m(q, 106, 106, today: later);
      expect(q.page(106).state, PageState.d1);
      expect(q.page(106).mCount, 2, reason: 'a new entry');
      expect(q.page(106).dEntries, 2);
      expect(q.page(106).mRepeated, isFalse);

      q = m(q, 106, 106, today: later);
      expect(q.page(106).mRepeated, isTrue);
      expect(q.page(106).mCount, 2);

      final third = engine.applyM(q: q, range: const PageRange(106, 106), today: later);
      expect(third.violationOrNull?.reason, RuleViolationReason.pageNotEligibleForM);
    });

    test('a page of the initial range also takes its repeat once (p 293)', () {
      final q = engine.createQ(
        id: 'q',
        totalPages: 604,
        initialMainD: const PageRange(282, 322),
        today: day0,
      );

      final once = m(q, 293, 293, today: day1);
      expect(once.page(293).mRepeated, isTrue);
      expect(once.page(293).mCount, 1);
      final twice = engine.applyM(q: once, range: const PageRange(293, 293), today: day1);
      expect(twice.violationOrNull?.reason, RuleViolationReason.pageNotEligibleForM);
    });
  });
}
