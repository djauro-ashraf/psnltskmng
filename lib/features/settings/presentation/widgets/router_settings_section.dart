import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/agent/controller/agent_providers.dart';
import 'package:personaltskmng/agent/models/agent_settings.dart';
import 'package:personaltskmng/agent/routing/agent_router.dart';
import 'package:personaltskmng/ai/ai_provider.dart';
import 'package:personaltskmng/ai/openai_compat.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/agent/presentation/agent_text.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// The router of the agent: how a request is sorted into what the AI is taught
/// (see `AgentRouter`), and the one thing that is set up for it, a dedicated
/// sorter.
///
/// The sorter is optional and has a card of its own so that nobody takes it for
/// part of the agent's key: two plain fields (the Cloudflare account ID and an
/// API token), what is saved, and a Test that tries it. Empty, half filled or
/// failing, the agent's own provider sorts instead, and if that fails the words
/// of the request decide: the sorter can only make things better, never break
/// them.
class RouterSettingsSection extends ConsumerStatefulWidget {
  const RouterSettingsSection({super.key});

  @override
  ConsumerState<RouterSettingsSection> createState() =>
      _RouterSettingsSectionState();
}

class _RouterSettingsSectionState extends ConsumerState<RouterSettingsSection> {
  final TextEditingController _account = TextEditingController();
  final TextEditingController _token = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _account.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final text = AgentText.of(context);
    final account = _account.text.trim();
    final token = _token.text.trim();
    if ((account.isEmpty && token.isEmpty) || _busy) return;
    if (account.isNotEmpty && !CloudflareRouterProvider.isValidAccount(account)) {
      showAppSnackBar(context, text.routerAccountInvalid, isError: true);
      return;
    }
    setState(() => _busy = true);
    var ok = true;
    try {
      final keys = ref.read(agentKeysProvider);
      if (account.isNotEmpty) await keys.write(routerAccountName, account);
      if (token.isNotEmpty) await keys.write(routerKeyName, token);
      ref.invalidate(agentRouterSetupProvider);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      _account.clear();
      _token.clear();
    }
    showAppSnackBar(
      context,
      ok ? l10n.aiKeySavedMessage : l10n.aiKeyFailed,
      isError: !ok,
    );
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    if (_busy) return;
    setState(() => _busy = true);
    var ok = true;
    try {
      final keys = ref.read(agentKeysProvider);
      await keys.delete(routerAccountName);
      await keys.delete(routerKeyName);
      ref.invalidate(agentRouterSetupProvider);
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showAppSnackBar(
      context,
      ok ? l10n.aiKeyRemovedMessage : l10n.aiKeyFailed,
      isError: !ok,
    );
  }

  /// Tries the sorter on a sample request and says what happened, in words: a
  /// success with the time it took, or the reason it failed (never the key).
  Future<void> _test() async {
    final text = AgentText.of(context);
    if (_busy) return;
    setState(() => _busy = true);
    final clock = Stopwatch()..start();
    String message;
    var isError = false;
    try {
      final sorter = CloudflareRouterProvider(
        keys: ref.read(agentKeysProvider),
        timeout: const Duration(seconds: 10),
      );
      final raw = await sorter.generateJson(
        system: AgentRouter.triageSystem,
        messages: [
          AiMessage(
            AiRole.user,
            AgentRouter.triageMessage('make my plans shorter'),
          ),
        ],
      );
      final picked = AgentRouter.parseTriage(raw);
      if (picked == null) {
        message = text.routerTestUnreadable;
        isError = true;
      } else {
        final names = picked.isEmpty
            ? '—'
            : [for (final module in picked) module.id].join(', ');
        message = text.routerTestOk(names, clock.elapsedMilliseconds);
      }
    } on AiProviderException catch (e) {
      message = text.routerTestFailed(_sentence(e.message));
      isError = true;
    } catch (_) {
      message = text.routerTestFailed('');
      isError = true;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    showAppSnackBar(context, message, isError: isError);
  }

  /// A reason with a full stop, so that it reads as a sentence.
  static String _sentence(String reason) {
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('.') ? trimmed : '$trimmed.';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = AgentText.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(agentSettingsProvider);
    final notifier = ref.read(agentSettingsProvider.notifier);
    final setup =
        ref.watch(agentRouterSetupProvider).value ?? RouterSetup.none;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text.routingHelp, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        Text(text.routingTitle, style: theme.textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final routing in AgentRouting.values)
              ChoiceChip(
                label: Text(text.routingName(routing)),
                selected: routing == settings.routing,
                onSelected: (_) => notifier.setRouting(routing),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          text.routingAbout(settings.routing),
          style: theme.textTheme.bodySmall,
        ),
        if (settings.routing == AgentRouting.smart) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(text.routerDedicatedTitle, style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(text.routerDedicatedHelp, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _account,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: text.routerAccountLabel),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _token,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            decoration: InputDecoration(labelText: text.routerTokenLabel),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(text.routerStatus(setup)),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              FilledButton.tonal(
                onPressed: _busy ? null : _save,
                child: Text(l10n.aiKeySave),
              ),
              OutlinedButton(
                onPressed: _busy || setup != RouterSetup.ready ? null : _test,
                child: Text(text.routerTest),
              ),
              TextButton(
                onPressed: _busy || setup == RouterSetup.none ? null : _remove,
                child: Text(l10n.aiKeyRemove),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
