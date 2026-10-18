import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/notes/controller/notes_controller.dart';
import 'package:personaltskmng/notes/data/day_log.dart';
import 'package:personaltskmng/notes/data/note_store.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

void main() {
  late DateTime now;
  late InMemoryNoteStore store;
  late InMemoryDayRecordStore records;
  late ProviderContainer container;

  NotesViewModel vm() => container.read(notesViewModelProvider.notifier);
  NotesState state() => container.read(notesViewModelProvider);

  setUp(() async {
    now = DateTime(2026, 10, 10, 9);
    store = InMemoryNoteStore();
    records = InMemoryDayRecordStore();
    final controller = NotesController(
      store: store,
      dayLog: dayLogReaderOf(records, () => 'q'),
    );
    await controller.load();
    container = ProviderContainer(
      overrides: [
        notesControllerProvider.overrideWithValue(controller),
        todayClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<void> logR(DateTime when, int from, int to, {bool ok = true}) =>
      records.save(
        DayRecord({
          'schema': 1,
          'qId': 'q',
          'day': Day.fromDateTime(when).toString(),
          'logged': [
            {'op': 'R', 'from': from, 'to': to, 'ok': ok},
          ],
        }),
      );

  test('add publishes the note and the open-note counts', () async {
    expect(await vm().add(page: 12, s: 2, ch: 3, text: 'a verb'), isTrue);
    expect(state().book.open.single.text, 'a verb');
    expect(state().index.onPage(12), 1);
    expect(state().index.inCh(3), 1);
    expect(state().today, Day.fromDateTime(now));
  });

  test('a blank note is refused and nothing is published', () async {
    expect(await vm().add(page: 12, s: 2, ch: 3, text: '  '), isFalse);
    expect(state().book.notes, isEmpty);
    expect(store.saves, 0);
  });

  test('a failed save reports false and changes nothing', () async {
    store.failOnSave = true;
    expect(await vm().add(page: 12, s: 2, ch: 3, text: 'x'), isFalse);
    expect(state().book.notes, isEmpty);
  });

  test('I remembered is pending today, and counted when the day ends', () async {
    await vm().add(page: 12, s: 2, ch: 3, text: 'x');
    final id = state().book.open.single.id;
    expect(await vm().remembered(id), isTrue);
    expect(state().book.byId(id)!.tappedOn(Day.fromDateTime(now)), isTrue);
    expect(state().book.byId(id)!.count, 0);

    await logR(now, 10, 20);
    now = DateTime(2026, 10, 11, 8); // the next morning
    await vm().refresh();

    final note = state().book.byId(id)!;
    expect(note.count, 1);
    expect(note.pending, isEmpty);
    expect(state().today, Day.fromDateTime(now));
  });

  test('without a covering success the tap disappears at day end', () async {
    await vm().add(page: 12, s: 2, ch: 3, text: 'x');
    final id = state().book.open.single.id;
    await vm().remembered(id);
    await logR(now, 10, 20, ok: false); // a failed R does not count
    now = DateTime(2026, 10, 11, 8);
    await vm().refresh();

    final note = state().book.byId(id)!;
    expect(note.count, 0);
    expect(note.pending, isEmpty);
  });

  test('refresh with nothing to judge keeps the very same state', () async {
    await vm().add(page: 12, s: 2, ch: 3, text: 'x');
    final before = state();
    await vm().refresh();
    expect(identical(state(), before), isTrue);
  });

  test('restore and delete go through the archive', () async {
    await vm().add(page: 12, s: 2, ch: 3, text: 'x');
    final id = state().book.open.single.id;
    for (var i = 0; i < 5; i++) {
      await logR(now, 12, 12);
      await vm().remembered(id);
      now = now.add(const Duration(days: 1));
      await vm().refresh();
    }
    expect(state().book.byId(id)!.isArchived, isTrue);
    expect(state().archivedWhere((n) => n.page == 12).length, 1);
    expect(state().openWhere((n) => true), isEmpty);

    await vm().restore(id);
    expect(state().book.byId(id)!.isOpen, isTrue);
    expect(state().book.byId(id)!.count, 0);
  });

  test('openWhere lists by page, notes of a page in the order added', () async {
    await vm().add(page: 30, s: 2, ch: 4, text: 'late page');
    await vm().add(page: 12, s: 2, ch: 3, text: 'first on 12');
    await vm().add(page: 12, s: 2, ch: 3, text: 'second on 12');
    expect(
      state().openWhere((n) => true).map((n) => n.text),
      ['first on 12', 'second on 12', 'late page'],
    );
  });
}
