import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/memo/presentation/log_actions.dart';
import 'package:personaltskmng/features/memo/presentation/memo_text.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/memo/models/memo_event.dart';
import 'package:personaltskmng/memo/rules/memo_rules.dart';
import 'package:personaltskmng/memo/rules/range_input.dart';

/// The typed way to log, for when the thing done is not a whole piece you can
/// tap: Memorise or Review, and what (a page, a piece of any partition, ayahs:
/// see `RangeInput`). Shows what the text means and what the rule would leave
/// out before anything is written. The day comes from `logDayProvider`.
class LogCard extends ConsumerStatefulWidget {
  const LogCard({super.key});

  @override
  ConsumerState<LogCard> createState() => _LogCardState();
}

class _LogCardState extends ConsumerState<LogCard> {
  final TextEditingController _text = TextEditingController();
  MemoKind _kind = MemoKind.r;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _log() async {
    final memo = ref.read(memoProvider);
    final text = MemoText.of(context);
    final parsed = RangeInput.parse(_text.text, memo.partitions);
    final span = parsed.span;
    if (span == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(text.inputProblem(parsed.problem!))));
      return;
    }
    setState(() => _busy = true);
    final result = await logAndNotify(context, ref, kind: _kind, span: span);
    if (!mounted) return;
    if (result != null && result.wroteAnything) _text.clear();
    setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final text = MemoText.of(context);
    final theme = Theme.of(context);
    final memo = ref.watch(memoProvider);
    final input = _text.text.trim();
    final parsed = input.isEmpty ? null : RangeInput.parse(input, memo.partitions);
    String? error;
    String? preview;
    var previewIsWarning = false;
    if (parsed != null) {
      final span = parsed.span;
      if (span == null) {
        error = text.inputProblem(parsed.problem!);
      } else {
        preview = '${span.label} · ${span.length} ayahs';
        if (memo.settings.sensible) {
          final plan = MemoRules.plan(
            kind: _kind,
            span: span,
            view: memo.view,
            sensible: true,
          );
          if (plan.isEmpty) {
            preview = text.nothingFits(_kind);
            previewIsWarning = true;
          } else if (plan.skipped > 0) {
            preview = '$preview · ${plan.skipped} left out';
            previewIsWarning = true;
          }
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<MemoKind>(
          segments: [
            ButtonSegment(value: MemoKind.m, label: Text(text.kind(MemoKind.m))),
            ButtonSegment(value: MemoKind.r, label: Text(text.kind(MemoKind.r))),
          ],
          selected: {_kind},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _kind = s.first),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _text,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          decoration: InputDecoration(
            hintText: text.logHint,
            errorText: error,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => unawaited(_log()),
        ),
        if (preview != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            preview,
            style: theme.textTheme.bodySmall?.copyWith(
              color: previewIsWarning
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            onPressed: _busy ? null : () => unawaited(_log()),
            child: Text(text.logButton),
          ),
        ),
      ],
    );
  }
}
