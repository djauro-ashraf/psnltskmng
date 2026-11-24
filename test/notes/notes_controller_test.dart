import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import '../support/fake_day_log.dart';

const Day _d0 = Day(20000);

Day _day(int n) => Day(20000 + n);

void main() {
  group('NotesController', () {
    late InMemoryNoteStore store;
    late FakeDayLog records;
    late NotesController controller;

    setUp(() async {
      store = InMemoryNoteStore();
      records = FakeDayLog();
      controller = NotesController(
        store: store,
        dayLog: records.reader,
      );
      await controller.load();
    });

    test('add saves first and returns the note; blank saves nothing', () async {
      final note = await controller.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'hello',
        today: _d0,
      );
      expect(note!.id, 'n1');
      expect(store.saves, 1);
      expect(controller.book.open.length, 1);

      final none = await controller.add(
        page: 12,
        s: 2,
        ch: 2,
        text: ' ',
        today: _d0,
      );
      expect(none, isNull);
      expect(store.saves, 1);
    });

    test('a failed save leaves the book as it was and reaches the caller', () async {
      store.failOnSave = true;
      await expectLater(
        controller.add(page: 12, s: 2, ch: 2, text: 'hello', today: _d0),
        throwsStateError,
      );
      expect(controller.book.notes, isEmpty);

      // The queue is not stuck: the next call works.
      store.failOnSave = false;
      final note = await controller.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'hello',
        today: _d0,
      );
      expect(note, isNotNull);
    });

    test('the book survives a reload from the file', () async {
      await controller.add(page: 12, s: 2, ch: 2, text: 'hello', today: _d0);
      final again = NotesController(store: store);
      await again.load();
      expect(again.book.open.single.text, 'hello');
    });

    test('a tap counts when the day log has a covering R, at day end', () async {
      final note = (await controller.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'hello',
        today: _d0,
      ))!;
      await records.logR(_d0, 10, 20);

      await controller.tap(note.id, _d0);
      // Same day: not judged, shown as a pending tick only.
      expect(controller.book.byId(note.id)!.count, 0);
      expect(controller.book.byId(note.id)!.tappedOn(_d0), isTrue);

      await controller.settle(_day(1));
      expect(controller.book.byId(note.id)!.count, 1);
      expect(controller.book.byId(note.id)!.pending, isEmpty);
    });

    test('a tap with no covering success vanishes silently', () async {
      final note = (await controller.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'hello',
        today: _d0,
      ))!;
      // Nothing was logged that day (an M, or an R that changed nothing, is not
      // an R in the day log), so the tap is not covered.
      await controller.tap(note.id, _d0);
      await controller.settle(_day(1));

      final judged = controller.book.byId(note.id)!;
      expect(judged.count, 0);
      expect(judged.pending, isEmpty);
      expect(judged.isOpen, isTrue);
    });

    test('five counted days resolve the note into the archive', () async {
      final note = (await controller.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'hello',
        today: _d0,
      ))!;
      for (final n in [0, 1, 3, 4, 8]) {
        await records.logR(_day(n), 12, 12);
        await controller.tap(note.id, _day(n));
        await controller.settle(_day(n + 1));
      }
      final resolved = controller.book.byId(note.id)!;
      expect(resolved.isArchived, isTrue);
      expect(resolved.count, 5);
      expect(controller.book.open, isEmpty);
    });

    test('a tap judges the days before it first, never against the wrong day', () async {
      final note = (await controller.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'hello',
        today: _d0,
      ))!;
      await records.logR(_d0, 12, 12);
      await controller.tap(note.id, _d0);

      // The app was not opened on day 1; on day 2 the tap of day 0 is judged
      // before the new tap is taken.
      await controller.tap(note.id, _day(2));
      final judged = controller.book.byId(note.id)!;
      expect(judged.counted, [_d0]);
      expect(judged.pending, [_day(2)]);
    });

    test('when the day log cannot be read nothing is judged', () async {
      var failing = true;
      final flaky = NotesController(
        store: store,
        dayLog: (day) async {
          if (failing) throw StateError('cannot read');
          return const [PageRange(12, 12)];
        },
      );
      await flaky.load();
      final note = (await flaky.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'hello',
        today: _d0,
      ))!;
      await flaky.tap(note.id, _d0);

      await flaky.settle(_day(1));
      expect(flaky.book.byId(note.id)!.pending, [_d0]); // still waiting
      expect(flaky.book.byId(note.id)!.count, 0);

      failing = false;
      await flaky.settle(_day(1));
      expect(flaky.book.byId(note.id)!.count, 1);
    });

    test('without a day log reader a tap is judged as not logged', () async {
      final bare = NotesController(store: store);
      await bare.load();
      final note = (await bare.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'hello',
        today: _d0,
      ))!;
      await bare.tap(note.id, _d0);
      await bare.settle(_day(1));
      expect(bare.book.byId(note.id)!.count, 0);
      expect(bare.book.byId(note.id)!.pending, isEmpty);
    });

    test('restore and delete: delete only in the archive', () async {
      final note = (await controller.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'hello',
        today: _d0,
      ))!;
      await controller.delete(note.id); // open: ignored
      expect(controller.book.notes.length, 1);

      for (final n in [0, 1, 2, 3, 4]) {
        await records.logR(_day(n), 12, 12);
        await controller.tap(note.id, _day(n));
        await controller.settle(_day(n + 1));
      }
      expect(controller.book.byId(note.id)!.isArchived, isTrue);

      await controller.restore(note.id);
      final restored = controller.book.byId(note.id)!;
      expect(restored.isOpen, isTrue);
      expect(restored.count, 0);
    });

    test('the controller never writes to the day log', () async {
      final note = (await controller.add(
        page: 12,
        s: 2,
        ch: 2,
        text: 'hello',
        today: _d0,
      ))!;
      await records.logR(_d0, 12, 12);
      final before = records.toString();
      await controller.tap(note.id, _d0);
      await controller.settle(_day(1));
      expect(records.toString(), before);
    });
  });
}
