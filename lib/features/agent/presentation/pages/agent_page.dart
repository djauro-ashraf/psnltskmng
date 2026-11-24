import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/agent/controller/agent_providers.dart';
import 'package:personaltskmng/agent/models/agent_command.dart';
import 'package:personaltskmng/agent/models/agent_turn.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/agent/presentation/agent_text.dart';
import 'package:personaltskmng/features/agent/presentation/providers/agent_controller.dart';
import 'package:personaltskmng/features/memo/presentation/providers/memo_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/memo/rules/memo_rules.dart';
import 'package:personaltskmng/shared/widgets/empty_state.dart';

/// The agent: a box to say what you want in your own words, and under it what
/// the AI understood and what the app did, with an Undo for what it logged.
/// A full screen above the tabs (see the router), opened by the command button.
///
/// When the instructions include opening a screen or a page, the app goes
/// there as soon as they are done; the conversation stays and is here again
/// when the button is tapped.
class AgentPage extends ConsumerStatefulWidget {
  const AgentPage({super.key});

  @override
  ConsumerState<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends ConsumerState<AgentPage> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final value = _input.text.trim();
    if (value.isEmpty || ref.read(agentControllerProvider).busy) return;
    _input.clear();
    unawaited(ref.read(agentControllerProvider.notifier).send(value));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _pick(String example) {
    _input.text = example;
    _input.selection = TextSelection.collapsed(offset: example.length);
  }

  @override
  Widget build(BuildContext context) {
    final text = AgentText.of(context);
    final available = ref.watch(agentAvailableProvider);
    final chat = ref.watch(agentControllerProvider);
    final notifier = ref.read(agentControllerProvider.notifier);

    // An `open` was carried out: go there (the conversation is kept).
    ref.listen<String?>(agentControllerProvider.select((s) => s.route), (
      previous,
      next,
    ) {
      if (next == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(agentControllerProvider.notifier).consumeRoute();
        context.go(next);
      });
    });
    ref.listen<AgentChatState>(
      agentControllerProvider,
      (previous, next) => _scrollToEnd(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(text.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: text.newConversation,
            onPressed: chat.turns.isEmpty || chat.busy ? null : notifier.clear,
          ),
        ],
      ),
      body: available
          ? _conversation(text, chat)
          : EmptyState(
              icon: Icons.auto_awesome_rounded,
              title: text.notReadyTitle,
              message: text.notReadyBody,
              actions: [
                FilledButton(
                  onPressed: () => context.go(AppRoutes.settings),
                  child: Text(text.openSettings),
                ),
              ],
            ),
    );
  }

  Widget _conversation(AgentText text, AgentChatState chat) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
        child: Column(
          children: [
            Expanded(
              child: chat.turns.isEmpty
                  ? _Intro(text: text, onPick: _pick)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: chat.turns.length,
                      itemBuilder: (context, index) =>
                          _TurnView(turn: chat.turns[index]),
                    ),
            ),
            _composer(text, chat.busy),
          ],
        ),
      ),
    );
  }

  Widget _composer(AgentText text, bool busy) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: text.hint,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              onPressed: busy ? null : _send,
              tooltip: text.send,
              icon: const Icon(Icons.arrow_upward_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the screen shows before the first request: what the agent is, and a few
/// requests to start from (a tap puts one in the box).
class _Intro extends StatelessWidget {
  const _Intro({required this.text, required this.onPick});

  final AgentText text;
  final void Function(String example) onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 40,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              text.intro,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final example in text.examples)
                  ActionChip(
                    label: Text(example),
                    onPressed: () => onPick(example),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One request of the user and the agent's side of it.
class _TurnView extends ConsumerWidget {
  const _TurnView({required this.turn});

  final AgentTurn turn;

  /// A line for an instruction that has not run yet, with what a log will do.
  static String _pendingLine(
    AgentText text,
    AgentCommand command,
    MemoState memo,
    Map<String, String> names,
  ) {
    if (command is LogCommand) {
      final plan = MemoRules.plan(
        kind: command.kind,
        span: command.span,
        view: memo.view,
        sensible: memo.settings.sensible,
      );
      return text.command(
        command,
        today: memo.today,
        willLog: plan.acceptedAyahs,
        skipped: plan.skipped,
      );
    }
    return text.command(command, today: memo.today, names: names);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = AgentText.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final memo = ref.watch(memoProvider);
    final book = ref.watch(notesViewModelProvider).book;
    // What the user knows the ids the AI used by: the names of their own
    // partitions and the text of their notes.
    final names = <String, String>{
      for (final p in memo.custom) p.id: p.name,
      for (final n in book.notes) n.id: n.text,
    };
    final controller = ref.read(agentControllerProvider.notifier);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final body = <Widget>[];
    void gap() => body.add(const SizedBox(height: AppSpacing.sm));

    if (turn.say.isNotEmpty) {
      body.add(Text(turn.say));
    }

    switch (turn.phase) {
      case AgentPhase.thinking:
        body.add(
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(text.thinking, style: muted),
            ],
          ),
        );
      case AgentPhase.failed:
        body.add(
          Text(
            text.failure(
              turn.failure ?? AgentFailure.other,
              message: turn.error,
              kind: turn.errorKind,
            ),
            style: TextStyle(color: scheme.error),
          ),
        );
        if (turn.errorKind == AiErrorKind.missingKey) {
          body.add(
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () => context.go(AppRoutes.settings),
                child: Text(text.openSettings),
              ),
            ),
          );
        }
      case AgentPhase.pending:
      case AgentPhase.running:
      case AgentPhase.cancelled:
        if (turn.phase == AgentPhase.pending) {
          gap();
          body.add(Text(text.pendingTitle, style: theme.textTheme.labelLarge));
        }
        gap();
        for (final command in turn.commands) {
          body.add(
            _Line(
              icon: command.alwaysAsk
                  ? Icons.warning_amber_rounded
                  : Icons.arrow_right_alt_rounded,
              color: command.alwaysAsk ? scheme.error : scheme.onSurfaceVariant,
              text: _pendingLine(text, command, memo, names),
            ),
          );
        }
        if (turn.phase == AgentPhase.pending &&
            turn.commands.any((c) => c.alwaysAsk)) {
          gap();
          body.add(
            Text(
              text.destructiveWarning,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
            ),
          );
        }
        if (turn.phase == AgentPhase.pending) {
          gap();
          body.add(
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => controller.cancel(turn.id),
                  child: Text(text.cancel),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: () => unawaited(controller.approve(turn.id)),
                  child: Text(text.run),
                ),
              ],
            ),
          );
        } else if (turn.phase == AgentPhase.running) {
          gap();
          body.add(const LinearProgressIndicator());
        } else {
          gap();
          body.add(Text(text.cancelled, style: muted));
        }
      case AgentPhase.done:
        if (turn.commands.isEmpty && turn.say.isEmpty) {
          body.add(Text(text.nothingToDo, style: muted));
        }
        if (turn.results.isNotEmpty) gap();
        for (final result in turn.results) {
          body.add(
            _Line(
              icon: switch (result.kind) {
                AgentResultKind.done => Icons.check_circle_outline_rounded,
                AgentResultKind.nothingFits => Icons.info_outline_rounded,
                AgentResultKind.failed => Icons.error_outline_rounded,
                AgentResultKind.unavailable => Icons.block_rounded,
              },
              color: switch (result.kind) {
                AgentResultKind.done => scheme.primary,
                AgentResultKind.failed => scheme.error,
                _ => scheme.onSurfaceVariant,
              },
              text: text.result(result, today: memo.today, names: names),
            ),
          );
        }
        if (turn.dropped > 0) {
          gap();
          body.add(Text(text.dropped(turn.dropped), style: muted));
        }
        if (turn.canUndo) {
          body.add(
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => unawaited(controller.undoTurn(turn.id)),
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: Text(text.undo),
              ),
            ),
          );
        } else if (turn.undone) {
          gap();
          body.add(Text(text.undone, style: muted));
        }
    }

    if (turn.phase != AgentPhase.done && turn.dropped > 0) {
      gap();
      body.add(Text(text.dropped(turn.dropped), style: muted));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: Text(
                turn.userText,
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
