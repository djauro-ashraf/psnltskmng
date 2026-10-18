import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/backup/presentation/providers/backup_providers.dart';
import 'package:personaltskmng/features/backup/services/drive_auth.dart';
import 'package:personaltskmng/features/backup/services/drive_backup_service.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/planning_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/today_view_model.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';
import 'package:personaltskmng/shared/widgets/app_snackbar.dart';

/// After a backup was restored, the screens read the restored data: the
/// settings, the planning status, today's session and the notes.
void refreshAfterRestore(WidgetRef ref) {
  ref.invalidate(settingsViewModelProvider);
  ref.read(settingsRevisionProvider.notifier).bump();
  ref.invalidate(planningViewModelProvider);
  ref.invalidate(todayViewModelProvider);
  ref.read(notesViewModelProvider.notifier).refresh();
}

/// Opens a modal dialog to export the full application backup.
Future<void> showExportBackupDialog(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(planningControllerProvider);
  final settingsRepo = ref.read(settingsRepositoryProvider);
  final dayRecords = ref.read(dayRecordStoreProvider);
  final backupService = ref.read(backupServiceProvider);
  final notes = ref.read(notesControllerProvider);

  try {
    final backup = await backupService.createBackup(
      controller: controller,
      settingsRepo: settingsRepo,
      dayRecordsStore: dayRecords,
      notes: notes,
    );

    final jsonString = backup.toJsonString();
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download_rounded),
            SizedBox(width: AppSpacing.sm),
            Text('Export Backup'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy or save your backup. You can import this data on any other device '
                'to restore your exact learning state, settings, and study history.',
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Pages in Q: ${backup.state.q.totalPages}'),
                    Text('• Study History: ${backup.dayRecords.length} days logged'),
                    Text('• Notes: ${backup.notes?.notes.length ?? 0}'),
                    Text('• Exported: ${backup.exportedAt.toLocal().toString().split('.')[0]}'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 120,
                child: TextField(
                  controller: TextEditingController(text: jsonString),
                  readOnly: true,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Backup JSON',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: jsonString));
              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                showAppSnackBar(context, 'Backup copied to clipboard!');
              }
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, 'Failed to generate backup: $e', isError: true);
    }
  }
}

/// Opens a modal dialog to paste and restore an exported backup.
Future<void> showImportBackupDialog(BuildContext context, WidgetRef ref) async {
  final textController = TextEditingController();

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.upload_rounded),
          SizedBox(width: AppSpacing.sm),
          Text('Import Backup'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your backup JSON below to restore your learning progress, '
              'history, and preferences from another device.',
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: textController,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste backup JSON here...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final raw = textController.text.trim();
            if (raw.isEmpty) return;

            final controller = ref.read(planningControllerProvider);
            final settingsRepo = ref.read(settingsRepositoryProvider);
            final dayRecords = ref.read(dayRecordStoreProvider);
            final backupService = ref.read(backupServiceProvider);
            final notes = ref.read(notesControllerProvider);

            try {
              final restored = await backupService.restoreFromJson(
                raw,
                controller: controller,
                settingsRepo: settingsRepo,
                dayRecordsStore: dayRecords,
                notes: notes,
              );
              refreshAfterRestore(ref);

              if (ctx.mounted) {
                Navigator.of(ctx).pop();
                showAppSnackBar(
                  context,
                  'Data restored successfully! Loaded ${restored.dayRecords.length} days of history'
                  '${restored.notes == null ? '' : ' and ${restored.notes!.notes.length} notes'}.',
                );
              }
            } catch (e) {
              if (ctx.mounted) {
                showAppSnackBar(
                  ctx,
                  'Failed to import backup: invalid data format.',
                  isError: true,
                );
              }
            }
          },
          icon: const Icon(Icons.restore_rounded),
          label: const Text('Restore Data'),
        ),
      ],
    ),
  );
}

/// Opens the Google Drive dialog: connect (the user approves a code on
/// google.com/device), back up now, restore, disconnect, and how often to back
/// up on its own.
Future<void> showGoogleDriveDialog(BuildContext context, WidgetRef ref) =>
    showDialog<void>(
      context: context,
      builder: (_) => GoogleDriveDialog(parentRef: ref),
    );

class GoogleDriveDialog extends ConsumerStatefulWidget {
  const GoogleDriveDialog({super.key, required this.parentRef});

  /// The ref of the screen that opened the dialog, kept for what must outlive
  /// the dialog (the refresh after a restore).
  final WidgetRef parentRef;

  @override
  ConsumerState<GoogleDriveDialog> createState() => _GoogleDriveDialogState();
}

class _GoogleDriveDialogState extends ConsumerState<GoogleDriveDialog> {
  DriveConnectionStatus? _status;
  DeviceCode? _code;
  bool _connecting = false;
  bool _cancelled = false;
  String? _working; // what is running ("Backing up..."), or null
  String? _error;

  DriveBackupService get _service => ref.read(driveBackupServiceProvider);

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _cancelled = true; // stops the wait for an approval
    super.dispose();
  }

  Future<void> _loadStatus() async {
    try {
      final status = await _service.status();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) {
        setState(() => _status = const DriveConnectionStatus(isConnected: false));
      }
    }
  }

  Future<void> _connect() async {
    setState(() {
      _error = null;
      _connecting = true;
      _cancelled = false;
    });
    try {
      final code = await _service.beginConnect();
      if (!mounted) return;
      setState(() => _code = code);
      final account = await _service.finishConnect(
        code,
        cancelled: () => !mounted || _cancelled,
      );
      await ref
          .read(settingsViewModelProvider.notifier)
          .setGoogleDriveConnected(true, email: account.email);
      if (!mounted) return;
      showAppSnackBar(context, 'Google Drive connected: ${account.email}');
    } catch (e) {
      if (mounted && !_cancelled) setState(() => _error = '$e');
    } finally {
      if (mounted) {
        setState(() {
          _code = null;
          _connecting = false;
        });
        await _loadStatus();
      }
    }
  }

  Future<void> _disconnect() async {
    await _service.disconnectDrive();
    await ref
        .read(settingsViewModelProvider.notifier)
        .setGoogleDriveConnected(false);
    await _loadStatus();
  }

  Future<void> _backupNow() async {
    setState(() {
      _error = null;
      _working = 'Backing up to Google Drive…';
    });
    try {
      await _service.uploadBackupToDrive(
        controller: ref.read(planningControllerProvider),
        settingsRepo: ref.read(settingsRepositoryProvider),
        dayRecordsStore: ref.read(dayRecordStoreProvider),
        notes: ref.read(notesControllerProvider),
      );
      await ref
          .read(settingsViewModelProvider.notifier)
          .updateLastBackupTime(DateTime.now());
      if (mounted) showAppSnackBar(context, 'Backup saved to Google Drive.');
    } catch (e) {
      if (mounted) setState(() => _error = 'Backup failed: $e');
    } finally {
      if (mounted) {
        setState(() => _working = null);
        await _loadStatus();
      }
    }
  }

  Future<void> _restore() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Google Drive?'),
        content: const Text(
          'This replaces the progress, settings, study history and notes on '
          'this device with the backup on Google Drive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    setState(() {
      _error = null;
      _working = 'Restoring from Google Drive…';
    });
    try {
      final restored = await _service.restoreFromDrive(
        controller: ref.read(planningControllerProvider),
        settingsRepo: ref.read(settingsRepositoryProvider),
        dayRecordsStore: ref.read(dayRecordStoreProvider),
        notes: ref.read(notesControllerProvider),
      );
      refreshAfterRestore(widget.parentRef);
      if (!mounted) return;
      Navigator.of(context).pop();
      showAppSnackBar(
        context,
        'Restored from Google Drive: ${restored.dayRecords.length} days of history'
        '${restored.notes == null ? '' : ' and ${restored.notes!.notes.length} notes'}.',
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Restore failed: $e');
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = _status;
    final configured = _service.isConfigured;
    final frequency = ref.watch(settingsViewModelProvider).backupFrequency;

    final body = <Widget>[
      const Text(
        'Back up your progress, settings, study history and notes to your own '
        'Google Drive (a hidden app folder only this app can see), and restore '
        'them on this or another device.',
      ),
      const SizedBox(height: AppSpacing.lg),
    ];

    if (status == null) {
      body.add(const Center(child: CircularProgressIndicator()));
    } else if (!configured) {
      body.add(
        Text(
          'Google Drive is not set up in this build. It needs a Google OAuth '
          'client; docs/DRIVE_SETUP.md says how to make one. Until then, use '
          'Export Backup and Import Backup.',
          style: TextStyle(color: scheme.error),
        ),
      );
    } else if (!status.isConnected) {
      final code = _code;
      if (code == null) {
        body.add(
          FilledButton.icon(
            onPressed: _connecting ? null : _connect,
            icon: const Icon(Icons.link_rounded),
            label: const Text('Connect Google Drive'),
          ),
        );
      } else {
        body.add(_CodeCard(code: code));
        body.add(const SizedBox(height: AppSpacing.sm));
        body.add(
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(child: Text('Waiting for you to approve it…')),
              TextButton(
                onPressed: () => setState(() => _cancelled = true),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
    } else {
      final last = status.lastBackupTime;
      body.addAll([
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: scheme.onPrimaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Connected: ${status.accountEmail}',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _working == null ? _disconnect : null,
                child: const Text('Disconnect'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Last backup from this device: '
          '${last == null ? 'Never' : last.toLocal().toString().split('.')[0]}',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _working == null ? _backupNow : null,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Backup Now'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _working == null ? _restore : null,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Restore'),
              ),
            ),
          ],
        ),
      ]);
    }

    final working = _working;
    if (working != null) {
      body.addAll([
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(working)),
          ],
        ),
      ]);
    }
    final error = _error;
    if (error != null) {
      body.addAll([
        const SizedBox(height: AppSpacing.md),
        Text(error, style: TextStyle(color: scheme.error)),
      ]);
    }

    body.addAll([
      const SizedBox(height: AppSpacing.lg),
      const Divider(),
      const SizedBox(height: AppSpacing.sm),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Auto-Backup Frequency:'),
          DropdownButton<String>(
            value: frequency,
            items: const [
              DropdownMenuItem(value: 'manual', child: Text('Manual only')),
              DropdownMenuItem(value: 'daily', child: Text('Daily')),
              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
            ],
            onChanged: (val) {
              if (val != null) {
                ref
                    .read(settingsViewModelProvider.notifier)
                    .setBackupFrequency(val);
              }
            },
          ),
        ],
      ),
      const Text(
        'An automatic backup is made when the app starts or comes back and the '
        'last one is older than this.',
      ),
    ]);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_sync_rounded),
          SizedBox(width: AppSpacing.sm),
          Text('Google Drive Backup'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: body,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// The code to approve: where to go and what to type.
class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final DeviceCode code;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('On any device, open this page and sign in to Google:'),
          Row(
            children: [
              Expanded(child: SelectableText(code.verificationUrl)),
              IconButton(
                tooltip: 'Copy the address',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: code.verificationUrl)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Text('Then enter this code:'),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  code.userCode,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    letterSpacing: 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy the code',
                icon: const Icon(Icons.copy_rounded),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: code.userCode)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
