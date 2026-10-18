import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/planning/data/json_dir_day_record_store.dart';
import 'package:personaltskmng/planning/day/day_record.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('qrm_records_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('one file per (Q, day); saving again replaces it; readAll returns plain JSON', () async {
    final store = JsonDirDayRecordStore(Directory('${tmp.path}/records'));
    await store.save(const DayRecord({'schema': 1, 'qId': 'q 1', 'day': '2026-09-30', 'x': 1}));
    await store.save(const DayRecord({'schema': 1, 'qId': 'q 1', 'day': '2026-09-30', 'x': 2}));
    await store.save(const DayRecord({'schema': 1, 'qId': 'q 1', 'day': '2026-10-01', 'x': 3}));

    final all = await store.readAll();
    expect(all.map((r) => r['x']), [2, 3]);
  });

  test('an empty or missing directory reads as no records', () async {
    final store = JsonDirDayRecordStore(Directory('${tmp.path}/nothing_here'));
    expect(await store.readAll(), isEmpty);
  });

  test('read returns the one record of a (Q, day), or null when there is none', () async {
    final store = JsonDirDayRecordStore(Directory('${tmp.path}/records'));
    expect(await store.read('q 1', '2026-09-30'), isNull); // no directory yet

    await store.save(const DayRecord({'schema': 1, 'qId': 'q 1', 'day': '2026-09-30', 'x': 1}));
    expect((await store.read('q 1', '2026-09-30'))!['x'], 1);
    expect(await store.read('q 1', '2026-10-01'), isNull); // another day
    expect(await store.read('q 2', '2026-09-30'), isNull); // another Q
  });

  test('a record that cannot be read throws, it is not "no record"', () async {
    final dir = Directory('${tmp.path}/records')..createSync(recursive: true);
    File('${dir.path}/q_1_2026-09-30.json').writeAsStringSync('{half written');
    File('${dir.path}/q_1_2026-10-01.json').writeAsStringSync('[1, 2]');
    final store = JsonDirDayRecordStore(dir);

    await expectLater(store.read('q 1', '2026-09-30'), throwsFormatException);
    await expectLater(store.read('q 1', '2026-10-01'), throwsFormatException);
  });
}
