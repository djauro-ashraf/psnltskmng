import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/page_range.dart';

/// Strict reading of decoded JSON for the storage codecs. Pure Dart. Every
/// problem is a [FormatException] whose message starts with the path of the
/// value (`q.pages[3].state: ...`), so a failed load can say exactly what is
/// wrong.
final class JsonObject {
  JsonObject(this.map, this.path);

  factory JsonObject.of(Object? value, String path) {
    if (value is Map) {
      for (final key in value.keys) {
        if (key is! String) {
          throw FormatException('$path: object keys must be strings');
        }
      }
      return JsonObject(Map<String, Object?>.from(value), path);
    }
    throw FormatException('$path: expected an object');
  }

  final Map<String, Object?> map;
  final String path;

  String _at(String key) => '$path.$key';

  bool has(String key) => map.containsKey(key);

  int integer(String key) {
    final v = map[key];
    if (v is int) return v;
    if (v is double && v.isFinite && v == v.truncateToDouble()) {
      return v.toInt();
    }
    throw FormatException('${_at(key)}: expected an integer, got $v');
  }

  int? integerOrNull(String key) => map[key] == null ? null : integer(key);

  double number(String key) {
    final v = map[key];
    if (v is num && v.isFinite) return v.toDouble();
    throw FormatException('${_at(key)}: expected a number, got $v');
  }

  bool boolean(String key) {
    final v = map[key];
    if (v is bool) return v;
    throw FormatException('${_at(key)}: expected true or false, got $v');
  }

  String string(String key) {
    final v = map[key];
    if (v is String) return v;
    throw FormatException('${_at(key)}: expected a string, got $v');
  }

  JsonObject object(String key) => JsonObject.of(map[key], _at(key));

  List<Object?> list(String key) {
    final v = map[key];
    if (v is List) return v;
    throw FormatException('${_at(key)}: expected a list, got $v');
  }

  /// The objects of the list at [key], each with its own path.
  List<JsonObject> objects(String key) {
    final items = list(key);
    return [
      for (var i = 0; i < items.length; i++)
        JsonObject.of(items[i], '${_at(key)}[$i]'),
    ];
  }

  T enumByName<T extends Enum>(String key, List<T> values) {
    final name = string(key);
    for (final v in values) {
      if (v.name == name) return v;
    }
    throw FormatException('${_at(key)}: unknown value "$name"');
  }

  T? enumByNameOrNull<T extends Enum>(String key, List<T> values) =>
      map[key] == null ? null : enumByName(key, values);

  Day day(String key) => Day(integer(key));

  Day? dayOrNull(String key) => map[key] == null ? null : Day(integer(key));

  /// A page range written as `[start, end]`.
  PageRange range(String key) {
    final v = map[key];
    if (v is List &&
        v.length == 2 &&
        v[0] is int &&
        v[1] is int &&
        (v[0] as int) >= 1 &&
        (v[0] as int) <= (v[1] as int)) {
      return PageRange(v[0] as int, v[1] as int);
    }
    throw FormatException('${_at(key)}: expected a page range [start, end], got $v');
  }
}

List<int> rangeJson(PageRange range) => [range.start, range.end];
