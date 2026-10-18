import 'package:personaltskmng/domain/models/page_range.dart';
import 'package:personaltskmng/domain/models/page_state.dart';

enum RuleViolationReason {
  emptyRange,
  rangeOutOfBounds,
  pageNotEligibleForM,
  pageNotEligibleForR,
  pageAlreadyRToday,
  expansionDirectionViolated,
  expansionNotAdjacentToMain,
  noMainDRange,

  /// A successful R or L touched a merged ch without covering all its owned
  /// pages (see `MergeRules`). The violation names the ch in [RuleViolation.ch].
  mergedChPartial,
}

/// Why an M/R operation (direct or AI-proposed) was rejected. Carries the
/// specific page/range and states involved so the UI or AI layer can build an
/// explanation from deterministic facts (section 39), never from a generic
/// "invalid" message.
final class RuleViolation {
  const RuleViolation(
    this.reason, {
    this.range,
    this.page,
    this.pageState,
    this.detail,
    this.ch,
  });

  final RuleViolationReason reason;
  final PageRange? range;
  final int? page;
  final PageState? pageState;
  final String? detail;

  /// The ch involved, for [RuleViolationReason.mergedChPartial].
  final int? ch;

  @override
  String toString() {
    final parts = [
      reason.name,
      if (range != null) 'range=$range',
      if (page != null) 'page=$page',
      if (pageState != null) 'state=${pageState!.name}',
      if (ch != null) 'ch=$ch',
      if (detail != null) detail,
    ];
    return parts.join(' ');
  }
}
