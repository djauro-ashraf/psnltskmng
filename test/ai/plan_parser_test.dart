import 'package:flutter_test/flutter_test.dart';
import 'package:personaltskmng/ai/plan_parser.dart';
import 'package:personaltskmng/planning/models/plan_violation.dart';

void main() {
  const parser = PlanParser();

  test('reads a clean plan', () {
    final p = parser.parse(
      '{"ops":[{"op":"R","from":282,"to":322,"why":"due tonight"},'
      '{"op":"m","from":323,"to":327}],"summary":"do both"}',
    );
    expect(p.failed, isFalse);
    expect(p.issues, isEmpty);
    expect(p.ops.map((o) => o.label), ['R 282-322', 'M 323-327']);
    expect(p.ops.first.note, 'due tonight');
    expect(p.summary, 'do both');
  });

  test('tolerates code fences, chatter and numeric strings', () {
    final p = parser.parse(
      'Here you go:\n```json\n{"ops":[{"op":"R","from":"10","to":12.0}]}\n```',
    );
    expect(p.ops.map((o) => o.label), ['R 10-12']);
  });

  test('an empty ops list is a valid plan', () {
    final p = parser.parse('{"ops":[]}');
    expect(p.failed, isFalse);
    expect(p.ops, isEmpty);
  });

  test('bad ops are reported by position, good ones survive', () {
    final p = parser.parse(
      '{"ops":[{"op":"X","from":1,"to":2},{"op":"R","from":9,"to":3},'
      '{"op":"R","from":5,"to":6}]}',
    );
    expect(p.ops.map((o) => o.label), ['R 5-6']);
    expect(p.issues.map((i) => i.opIndex), [0, 1]);
    expect(p.issues.every((i) => i.kind == ViolationKind.unparseable), isTrue);
  });

  test('garbage is a failed parse, not an exception', () {
    expect(parser.parse('sorry, I cannot').failed, isTrue);
    expect(parser.parse('{"ops": 3}').failed, isTrue);
    expect(parser.parse('{not json}').failed, isTrue);
  });
}
