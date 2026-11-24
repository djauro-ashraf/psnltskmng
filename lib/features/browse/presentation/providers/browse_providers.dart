import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/features/browse/domain/browse_data.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';

/// What the browse screens read besides the fixed tables: how each unit stands
/// and the open-note counts (see [BrowseData]). Read-only: nothing here changes
/// the log. Read again after every log. Tests may override this provider with a
/// [BrowseData] they built.
final browseDataProvider = Provider<BrowseData>((ref) {
  final memo = ref.watch(memoProvider);
  final index = ref.watch(notesViewModelProvider.select((state) => state.index));
  return BrowseData.build(
    view: memo.view,
    pages: memo.pages,
    day: memo.today,
    notes: index,
  );
});
