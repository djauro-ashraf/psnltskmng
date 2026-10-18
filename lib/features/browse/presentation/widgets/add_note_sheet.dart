import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/browse/domain/note_unit.dart';
import 'package:personaltskmng/features/browse/presentation/browse_texts.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// Opens the "new note" sheet for [unit]: a text card on a page.
Future<void> showAddNoteSheet(BuildContext context, NoteUnit unit) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AddNoteSheet(unit: unit),
    );

/// The "+" of a unit screen: the text of the note, the page (fixed on a page
/// screen, typed within the unit's range elsewhere) and, when that page is
/// shared by several s or ch, which one the note is filed under, with the
/// earlier ch pre-selected (the unit the screen is about, when it has one, wins
/// over that default so the new card stays on the screen it was added on).
class AddNoteSheet extends ConsumerStatefulWidget {
  const AddNoteSheet({super.key, required this.unit});

  final NoteUnit unit;

  @override
  ConsumerState<AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<AddNoteSheet> {
  late final TextEditingController _text = TextEditingController();
  late final TextEditingController _page = TextEditingController(
    text: '${widget.unit.firstPage}',
  );
  List<NoteHome> _homes = const [];
  NoteHome? _home;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _syncHomes();
  }

  @override
  void dispose() {
    _text.dispose();
    _page.dispose();
    super.dispose();
  }

  /// The page typed (or fixed by the screen), or null when it is not a page of
  /// the unit.
  int? get _pageValue {
    final fixed = widget.unit.page;
    if (fixed != null) return fixed;
    final value = int.tryParse(_page.text.trim());
    if (value == null || !widget.unit.containsPage(value)) return null;
    return value;
  }

  /// Reads the homes of the current page. Keeps the choice when it is still
  /// possible, otherwise pre-selects the earlier ch.
  void _syncHomes() {
    final page = _pageValue;
    if (page == null) {
      _homes = const [];
      _home = null;
      return;
    }
    final homes = noteHomesOfPage(page);
    final current = _home;
    _homes = homes;
    _home = current != null && homes.contains(current)
        ? current
        : preselectedHome(homes, s: widget.unit.s, ch: widget.unit.ch);
  }

  String _homeLabel(AppLocalizations l10n, NoteHome home) {
    final sameS = _homes.every((h) => h.s == _homes.first.s);
    final sameCh = _homes.every((h) => h.ch == _homes.first.ch);
    if (sameS) return l10n.chLabelOne(home.ch);
    if (sameCh) return l10n.sLabelOne(home.s);
    return l10n.browseTrail(l10n.sLabelOne(home.s), l10n.chLabelOne(home.ch));
  }

  Future<void> _save() async {
    final page = _pageValue;
    final home = _home;
    if (page == null || home == null || _saving) return;
    setState(() => _saving = true);
    final ok = await ref
        .read(notesViewModelProvider.notifier)
        .add(page: page, s: home.s, ch: home.ch, text: _text.text);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = false);
      showAppSnackBar(context, context.l10n.todayStorageError, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final unit = widget.unit;
    final page = _pageValue;
    final canSave =
        !_saving && page != null && _home != null && _text.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.noteAddTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.lg),
            if (unit.isPage)
              Text(
                l10n.pagesSingle(unit.firstPage),
                style: theme.textTheme.titleMedium,
              )
            else
              TextField(
                controller: _page,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.noteAddPage,
                  helperText: pagesLabel(l10n, unit.firstPage, unit.lastPage),
                  errorText: page == null
                      ? l10n.noteAddPageOutside(unit.firstPage, unit.lastPage)
                      : null,
                ),
                onChanged: (_) => setState(_syncHomes),
              ),
            if (_homes.length > 1) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(l10n.noteAddFiledUnder, style: theme.textTheme.labelLarge),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final home in _homes)
                    ChoiceChip(
                      label: Text(_homeLabel(l10n, home)),
                      selected: home == _home,
                      onSelected: (_) => setState(() => _home = home),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _text,
              autofocus: true,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l10n.noteAddText),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: canSave ? _save : null,
                  child: Text(l10n.noteAddSave),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
