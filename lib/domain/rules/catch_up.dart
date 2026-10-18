import 'package:personaltskmng/domain/models/day.dart';
import 'package:personaltskmng/domain/models/q.dart';

/// True when [q] has been settled at least through yesterday relative to
/// [today] (see `RulesEngine.catchUp`). Snapshots and plans require this: a
/// Q that is not settled still shows pages that have already degraded.
bool isSettledFor(Q q, Day today) {
  final done = q.evaluatedThrough;
  return done != null && !done.isBefore(today.plusDays(-1));
}
