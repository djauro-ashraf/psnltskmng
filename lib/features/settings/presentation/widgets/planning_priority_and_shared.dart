import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/domain/reference/ch_table.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/planning_draft.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/planning_fields.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/planning/config/planning_config.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';

String workClassLabel(AppLocalizations l10n, String name) => switch (name) {
  'recoverF3' => l10n.workClassRecoverF3,
  'expand' => l10n.workClassExpand,
  'workingSetR' => l10n.workClassWorkingSetR,
  'maintainC' => l10n.workClassMaintainC,
  _ => name,
};

/// The four priority classes as a reorderable list. The list is always the
/// four classes once each, so a duplicate cannot be made with this control.
class PriorityListTile extends StatelessWidget {
  const PriorityListTile({super.key, required this.draft});

  final PlanningDraft draft;

  static const String path = 'priority.order';

  List<String> _order() {
    final raw = draft.get(path);
    final all = [for (final w in WorkClass.values) w.name];
    final names = <String>[];
    if (raw is List) {
      for (final n in raw) {
        if (n is String && all.contains(n) && !names.contains(n)) names.add(n);
      }
    }
    for (final n in PriorityConfig.defaultOrder.map((w) => w.name)) {
      if (!names.contains(n)) names.add(n);
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) {
        final order = _order();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.priorityHint, style: Theme.of(context).textTheme.bodySmall),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorderItem: (from, to) {
                final next = [...order];
                final moved = next.removeAt(from);
                next.insert(to, moved);
                draft.set(path, next);
              },
              children: [
                for (var i = 0; i < order.length; i++)
                  ListTile(
                    key: ValueKey(order[i]),
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text('${i + 1}'),
                    ),
                    title: Text(workClassLabel(l10n, order[i])),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle_rounded),
                    ),
                  ),
              ],
            ),
            fieldError(context, draft.errorOf(path)),
          ],
        );
      },
    );
  }
}

/// The nested screen for the shared pages: the pages come from the ch table.
class SharedPagesScreen extends StatelessWidget {
  const SharedPagesScreen({super.key, required this.draft});

  final PlanningDraft draft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pages = ChTable.instance.sharedPages;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.sharedTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.formMaxWidth,
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: pages.length,
            itemBuilder: (context, i) =>
                _ShareRow(draft: draft, page: pages[i]),
          ),
        ),
      ),
    );
  }
}

class _ShareRow extends StatefulWidget {
  const _ShareRow({required this.draft, required this.page});

  final PlanningDraft draft;
  final int page;

  @override
  State<_ShareRow> createState() => _ShareRowState();
}

class _ShareRowState extends State<_ShareRow> {
  late final TextEditingController _controller = TextEditingController(
    text: formatNumber(widget.draft.shareOf(widget.page) ?? 0.5),
  );

  String get _errorPath => 'time.sharedPageShare[${widget.page}]';

  @override
  void initState() {
    super.initState();
    widget.draft.addListener(_sync);
  }

  @override
  void dispose() {
    widget.draft.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  Object? get _stored => widget.draft.shareOf(widget.page);

  void _sync() {
    final typed = parseNumber(_controller.text, isInt: false, nullable: false);
    final stored = _stored ?? 0.5;
    if (stored != typed) _controller.text = formatNumber(stored);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final chs = ChTable.instance.chOfPage(widget.page);
    final earlier = chs.first.number;
    final later = chs.last.number;
    final stored = _stored;
    final value = stored == null ? 0.5 : (stored is num ? stored.toDouble() : null);
    final v = value ?? 0.5;
    final inRange = value != null && v >= 0 && v <= 1;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.pagesSingle(widget.page),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(l10n.sharedChPair(earlier, later))),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]')),
                    ],
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (text) => widget.draft.setShare(
                      widget.page,
                      parseNumber(text, isInt: false, nullable: false),
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: v.clamp(0.0, 1.0).toDouble(),
              divisions: 20,
              label: inRange ? v.toStringAsFixed(2) : null,
              onChanged: (v) => widget.draft.setShare(
                widget.page,
                double.parse((v * 20).round().toString()) / 20,
              ),
            ),
            if (inRange)
              Text(
                l10n.sharedSplit(
                  earlier,
                  v.toStringAsFixed(2),
                  later,
                  (1 - v).toStringAsFixed(2),
                ),
              ),
            fieldError(context, widget.draft.errorOf(_errorPath)),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: stored == null
                    ? null
                    : () => widget.draft.setShare(widget.page, null),
                child: Text(l10n.sharedReset),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
