import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:personaltskmng/core/constants/app_breakpoints.dart';
import 'package:personaltskmng/core/constants/app_routes.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/core/errors/failure.dart';
import 'package:personaltskmng/features/backup/presentation/widgets/backup_dialogs.dart';
import 'package:personaltskmng/features/settings/domain/entities/app_settings.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';
import 'package:personaltskmng/features/agent/presentation/agent_text.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/agent_settings_section.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/ai_planner_section.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/ask_settings_section.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/memo_settings_sections.dart';
import 'package:personaltskmng/features/settings/presentation/widgets/router_settings_section.dart';
import 'package:personaltskmng/l10n/app_localizations.dart';
import 'package:personaltskmng/shared/extensions/l10n_x.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// The settings: appearance, backup, memorisation (the one rule of logging, the
/// numbers behind the statuses, the user's own partitions, the planner wishes),
/// the AI planner, the assistant, the agent and the Quran data. Every control here saves
/// as soon as it is changed; there is no draft and no Save button.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget _expansion(BuildContext context, String title, Widget child) => Card(
    margin: const EdgeInsets.only(bottom: AppSpacing.md),
    child: ExpansionTile(
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      childrenPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [child],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppBreakpoints.formMaxWidth),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              const _AppearanceSection(),
              const SizedBox(height: AppSpacing.md),
              const _BackupSection(),
              const MemoSettingsSection(),
              const SizedBox(height: AppSpacing.md),
              const PlannerWishesSection(),
              const SizedBox(height: AppSpacing.md),
              _expansion(context, l10n.settingsSectionAi, const AiPlannerSection()),
              _expansion(context, l10n.askSettingsTitle, const AskSettingsSection()),
              _expansion(
                context,
                AgentText.of(context).settingsTitle,
                const AgentSettingsSection(),
              ),
              _expansion(
                context,
                AgentText.of(context).routerSettingsTitle,
                const RouterSettingsSection(),
              ),
              const _QuranDataSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Theme, language and reading direction.
class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  Future<void> _apply(BuildContext context, Future<Failure?> action) async {
    final failure = await action;
    if (failure != null && context.mounted) {
      showFailureSnackBar(context, failure);
    }
  }

  String _themeLabel(AppLocalizations l10n, AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => l10n.settingsThemeSystem,
      AppThemeMode.light => l10n.settingsThemeLight,
      AppThemeMode.dark => l10n.settingsThemeDark,
    };
  }

  String _directionLabel(AppLocalizations l10n, ReadingDirection direction) {
    return switch (direction) {
      ReadingDirection.rightToLeft => l10n.settingsReadingRightToLeft,
      ReadingDirection.leftToRight => l10n.settingsReadingLeftToRight,
    };
  }

  IconData _themeIcon(AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.system => Icons.brightness_auto_outlined,
      AppThemeMode.light => Icons.light_mode_outlined,
      AppThemeMode.dark => Icons.dark_mode_outlined,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final settings = ref.watch(settingsViewModelProvider);
    final viewModel = ref.read(settingsViewModelProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsThemeSection, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<AppThemeMode>(
          showSelectedIcon: false,
          segments: [
            for (final mode in AppThemeMode.values)
              ButtonSegment<AppThemeMode>(
                value: mode,
                icon: Icon(_themeIcon(mode)),
                label: Text(_themeLabel(l10n, mode)),
              ),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (selection) =>
              _apply(context, viewModel.setThemeMode(selection.first)),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(l10n.settingsLanguageSection, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            ChoiceChip(
              label: Text(l10n.settingsLanguageSystem),
              selected: settings.localeCode == null,
              onSelected: (_) => _apply(context, viewModel.setLocaleCode(null)),
            ),
            // Built from the generated locales: adding an ARB file adds a chip.
            for (final locale in AppLocalizations.supportedLocales)
              ChoiceChip(
                label: Text(lookupAppLocalizations(locale).languageName),
                selected: settings.localeCode == locale.languageCode,
                onSelected: (_) => _apply(
                  context,
                  viewModel.setLocaleCode(locale.languageCode),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        // One setting for everything drawn in text order (see TextFlow).
        Text(
          l10n.settingsReadingDirectionSection,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.settingsReadingDirectionHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SegmentedButton<ReadingDirection>(
          showSelectedIcon: false,
          segments: [
            for (final direction in ReadingDirection.values)
              ButtonSegment<ReadingDirection>(
                value: direction,
                label: Text(_directionLabel(l10n, direction)),
              ),
          ],
          selected: {settings.readingDirection},
          onSelectionChanged: (selection) => _apply(
            context,
            viewModel.setReadingDirection(selection.first),
          ),
        ),
      ],
    );
  }
}

class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appSettings = ref.watch(settingsViewModelProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(
                    Icons.cloud_sync_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Cloud Backup & Device Sync',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Keep your learning data safe with Google Drive, or save a backup file where you choose and import it on any device.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                appSettings.googleDriveConnected
                    ? Icons.check_circle_rounded
                    : Icons.cloud_off_rounded,
                color: appSettings.googleDriveConnected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: Text(
                appSettings.googleDriveConnected
                    ? 'Google Drive Connected (${appSettings.googleDriveEmail ?? 'Active'})'
                    : 'Google Drive Disconnected',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Auto-backup: ${appSettings.backupFrequency} • Last synced: ${appSettings.lastBackupTime != null ? appSettings.lastBackupTime!.split('T')[0] : 'Never'}',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => showGoogleDriveDialog(context, ref),
                child: Text(
                  appSettings.googleDriveConnected ? 'Manage' : 'Connect',
                ),
              ),
            ),
            const Divider(height: AppSpacing.xl),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: () => showExportBackupDialog(context, ref),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Export Backup (JSON)'),
                ),
                OutlinedButton.icon(
                  onPressed: () => showImportBackupDialog(context, ref),
                  icon: const Icon(Icons.upload_rounded),
                  label: const Text('Import Backup (file or text)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The way to the Quran data screen, where the Quran, its words and its
/// translations are downloaded.
class _QuranDataSection extends StatelessWidget {
  const _QuranDataSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: ListTile(
        leading: const Icon(Icons.menu_book_rounded),
        title: Text(l10n.settingsQuranData),
        subtitle: Text(l10n.settingsQuranDataHint),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => context.push(AppRoutes.quranData),
      ),
    );
  }
}
