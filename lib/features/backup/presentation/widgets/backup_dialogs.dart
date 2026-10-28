import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:personaltskmng/core/constants/app_spacing.dart';
import 'package:personaltskmng/features/backup/data/backup_data.dart';
import 'package:personaltskmng/features/backup/presentation/providers/backup_providers.dart';
import 'package:personaltskmng/features/backup/services/backup_files.dart';
import 'package:personaltskmng/features/backup/services/drive_auth.dart';
import 'package:personaltskmng/features/backup/services/drive_backup_service.dart';
import 'package:personaltskmng/features/backup/services/drive_file_api.dart';
import 'package:personaltskmng/features/daily_plan/presentation/providers/planning_providers.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/planning_view_model.dart';
import 'package:personaltskmng/features/daily_plan/presentation/viewmodels/today_view_model.dart';
import 'package:personaltskmng/features/notes/presentation/providers/notes_providers.dart';
import 'package:personaltskmng/features/notes/presentation/viewmodels/notes_view_model.dart';
import 'package:personaltskmng/features/settings/presentation/providers/settings_providers.dart';
import 'package:personaltskmng/features/settings/presentation/viewmodels/settings_view_model.dart';
import 'package:personaltskmng/planning/controller/planning_controller.dart';
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

/// Whether this device already holds a set-up Q: a restore then replaces real
/// data (on a first run there is nothing to lose, so nothing to ask).
bool _hasDataHere(WidgetRef ref) =>
    ref.read(planningControllerProvider).status is PlanningLoaded;

String _formatTime(DateTime time) => time.toLocal().toString().split('.')[0];

/// "Loaded 40 days of history and 12 notes." for the snackbar after a restore.
String _restoredMessage(String from, BackupData restored) {
  final notes = restored.notes;
  return 'Restored from $from: ${restored.dayRecords.length} days of history'
      '${notes == null ? '' : ' and ${notes.notes.length} notes'}.';
}

String _withoutFinalDot(String text) =>
    text.endsWith('.') ? text.substring(0, text.length - 1) : text;

/// Why a text could not be read as a backup, for the user.
String _importFailure(Object error) => switch (error) {
  FormatException(:final message) =>
    'This is not a valid backup (${_withoutFinalDot(message)}).',
  TypeError() => 'This is not a valid backup (invalid data format).',
  _ => 'Failed to import backup: $error',
};

/// Asks before a restore replaces what is on this device. True = go on.
Future<bool> _confirmReplace(
  BuildContext context, {
  required String title,
  required String from,
}) async {
  final sure = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(
        'This replaces the progress, settings, study history and notes on '
        'this device with $from.',
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
  return sure == true;
}

/// What a backup holds: the box in the export dialog and the preview of a file
/// chosen for import.
class _BackupSummary extends StatelessWidget {
  const _BackupSummary({required this.backup});

  final BackupData backup;

  @override
  Widget build(BuildContext context) {
    final notes = backup.notes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• Pages in Q: ${backup.state.q.totalPages}'),
          Text('• Study History: ${backup.dayRecords.length} days logged'),
          Text(
            notes == null
                ? '• Notes: none in this backup (the ones here stay as they are)'
                : '• Notes: ${notes.notes.length}',
          ),
          Text('• Exported: ${_formatTime(backup.exportedAt)}'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Export
// ---------------------------------------------------------------------------

/// Opens a modal dialog to export the full application backup: save it as a
/// file (the user chooses where) or copy the text.
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
      builder: (_) =>
          _ExportBackupDialog(backup: backup, jsonString: jsonString),
    );
  } catch (e) {
    if (context.mounted) {
      showAppSnackBar(context, 'Failed to generate backup: $e', isError: true);
    }
  }
}

class _ExportBackupDialog extends ConsumerStatefulWidget {
  const _ExportBackupDialog({required this.backup, required this.jsonString});

  final BackupData backup;
  final String jsonString;

  @override
  ConsumerState<_ExportBackupDialog> createState() =>
      _ExportBackupDialogState();
}

class _ExportBackupDialogState extends ConsumerState<_ExportBackupDialog> {
  late final TextEditingController _json = TextEditingController(
    text: widget.jsonString,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  /// The system "save as" dialog (a download in a browser): the user picks the
  /// folder and the name.
  Future<void> _saveToFile() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(backupFilesProvider)
          .save(
            fileName: backupFileName(widget.backup.exportedAt),
            contents: widget.jsonString,
          );
      if (!mounted) return;
      if (!result.saved) {
        // The user closed the dialog without choosing a place: nothing to say.
        setState(() => _saving = false);
        return;
      }
      final location = result.location;
      Navigator.of(context).pop();
      showAppSnackBar(
        context,
        location != null
            ? 'Backup saved to $location'
            : kIsWeb
            ? 'Backup downloaded.'
            : 'Backup saved.',
      );
    } on BackupFileException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The backup file could not be saved: $e';
        });
      }
    }
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.jsonString));
    if (!mounted) return;
    Navigator.of(context).pop();
    showAppSnackBar(context, 'Backup copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final error = _error;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.download_rounded),
          SizedBox(width: AppSpacing.sm),
          Text('Export Backup'),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kIsWeb
                    ? 'Download your backup as a file, or copy the text. Your '
                          'browser saves downloads in its download folder, '
                          'unless it is set to ask where. You can import the '
                          'backup on any other device to restore your exact '
                          'learning state, settings, and study history.'
                    : 'Save your backup as a file and choose where it goes (a '
                          'folder, a USB drive, your cloud storage), or copy '
                          'the text. You can import it on any other device to '
                          'restore your exact learning state, settings, and '
                          'study history.',
              ),
              const SizedBox(height: AppSpacing.md),
              _BackupSummary(backup: widget.backup),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 120,
                child: TextField(
                  controller: _json,
                  readOnly: true,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Backup JSON',
                  ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(error, style: TextStyle(color: scheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        OutlinedButton.icon(
          onPressed: _saving ? null : _copy,
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy to Clipboard'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _saveToFile,
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(kIsWeb ? Icons.download_rounded : Icons.save_alt_rounded),
          label: Text(kIsWeb ? 'Download file' : 'Save to file…'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Import
// ---------------------------------------------------------------------------

/// Opens a modal dialog to restore an exported backup, from a file in storage
/// or from pasted text.
///
/// With [chooseFileFirst] the file chooser opens at once (the first-run screen's
/// "Import from file"); closing it leaves the dialog on its other choices.
Future<void> showImportBackupDialog(
  BuildContext context,
  WidgetRef ref, {
  bool chooseFileFirst = false,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _ImportBackupDialog(parentRef: ref, chooseFileFirst: chooseFileFirst),
);

class _ImportBackupDialog extends ConsumerStatefulWidget {
  const _ImportBackupDialog({
    required this.parentRef,
    required this.chooseFileFirst,
  });

  /// The ref of the screen that opened the dialog, kept for what must outlive
  /// the dialog (the refresh after a restore).
  final WidgetRef parentRef;
  final bool chooseFileFirst;

  @override
  ConsumerState<_ImportBackupDialog> createState() =>
      _ImportBackupDialogState();
}

class _ImportBackupDialogState extends ConsumerState<_ImportBackupDialog> {
  final TextEditingController _paste = TextEditingController();

  /// The file chosen from storage and what it holds, read before anything is
  /// restored so a file that is not a backup is refused at once.
  PickedBackupFile? _file;
  BackupData? _preview;

  bool _choosing = false;
  bool _restoring = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.chooseFileFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_chooseFile());
      });
    }
  }

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  bool get _busy => _choosing || _restoring;

  bool get _canRestore =>
      !_busy && (_file != null || _paste.text.trim().isNotEmpty);

  /// The system file chooser (storage on Android, the file dialog on Windows,
  /// the browser's chooser on the web).
  Future<void> _chooseFile() async {
    setState(() {
      _choosing = true;
      _error = null;
    });
    try {
      final picked = await ref.read(backupFilesProvider).pick();
      if (!mounted) return;
      if (picked == null) {
        // Closed without choosing: stay as it was.
        setState(() => _choosing = false);
        return;
      }
      final BackupData preview;
      try {
        preview = BackupData.fromJsonString(picked.contents);
      } catch (e) {
        setState(() {
          _choosing = false;
          _error = '"${picked.name}": ${_importFailure(e)}';
        });
        return;
      }
      setState(() {
        _choosing = false;
        _file = picked;
        _preview = preview;
      });
    } on BackupFileException catch (e) {
      if (mounted) {
        setState(() {
          _choosing = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _choosing = false;
          _error = 'The file could not be opened: $e';
        });
      }
    }
  }

  void _clearFile() {
    setState(() {
      _file = null;
      _preview = null;
      _error = null;
    });
  }

  Future<void> _restore() async {
    final file = _file;
    final raw = file?.contents ?? _paste.text.trim();
    if (raw.isEmpty) return;

    if (_hasDataHere(ref)) {
      final sure = await _confirmReplace(
        context,
        title: 'Restore this backup?',
        from: file == null ? 'the pasted backup' : 'the backup in "${file.name}"',
      );
      if (!sure || !mounted) return;
    }

    setState(() {
      _restoring = true;
      _error = null;
    });
    try {
      final restored = await ref
          .read(backupServiceProvider)
          .restoreFromJson(
            raw,
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
        'Data restored successfully! Loaded ${restored.dayRecords.length} days '
        'of history'
        '${restored.notes == null ? '' : ' and ${restored.notes!.notes.length} notes'}.',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _error = _importFailure(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = _file;
    final preview = _preview;
    final error = _error;

    return PopScope(
      // A restore that is writing must not be cut off by a tap outside.
      canPop: !_restoring,
      child: AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.upload_rounded),
            SizedBox(width: AppSpacing.sm),
            Text('Import Backup'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restore your learning progress, history, and preferences '
                  'from a backup made on this or another device.',
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _chooseFile,
                  icon: _choosing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open_rounded),
                  label: Text(
                    file == null
                        ? 'Choose backup file…'
                        : 'Choose another file…',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                if (file != null && preview != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.description_outlined),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          file.name,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove the file',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _busy ? null : _clearFile,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _BackupSummary(backup: preview),
                ] else ...[
                  Text(
                    'Or paste the backup text:',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _paste,
                    enabled: !_busy,
                    maxLines: 8,
                    onChanged: (_) => setState(() => _error = null),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Paste backup JSON here...',
                    ),
                  ),
                ],
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(error, style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _restoring ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: _canRestore ? _restore : null,
            icon: _restoring
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.restore_rounded),
            label: const Text('Restore Data'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Google Drive
// ---------------------------------------------------------------------------

/// Opens the Google Drive dialog: connect (the user approves a code on
/// google.com/device), back up now, restore, disconnect, and how often to back
/// up on its own.
Future<void> showGoogleDriveDialog(BuildContext context, WidgetRef ref) =>
    showDialog<void>(
      context: context,
      builder: (_) => GoogleDriveDialog(parentRef: ref),
    );

/// The Google Drive dialog of the first-run screen: only what a new install
/// needs. Connect the account, find the backup on Drive, restore it. No backup
/// now (there is nothing to back up yet) and no auto-backup setting.
Future<void> showGoogleDriveRestoreDialog(
  BuildContext context,
  WidgetRef ref,
) => showDialog<void>(
  context: context,
  builder: (_) => GoogleDriveDialog(parentRef: ref, restoreOnly: true),
);

class GoogleDriveDialog extends ConsumerStatefulWidget {
  const GoogleDriveDialog({
    super.key,
    required this.parentRef,
    this.restoreOnly = false,
  });

  /// The ref of the screen that opened the dialog, kept for what must outlive
  /// the dialog (the refresh after a restore).
  final WidgetRef parentRef;

  /// Only connect and restore (the first-run screen), see
  /// [showGoogleDriveRestoreDialog].
  final bool restoreOnly;

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

  // Restore-only: the backup found on Drive for the connected account.
  DriveBackupFile? _cloud;
  bool _cloudLooking = false;
  bool _cloudChecked = false;

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
    DriveConnectionStatus status;
    try {
      status = await _service.status();
    } catch (_) {
      status = const DriveConnectionStatus(isConnected: false);
    }
    if (!mounted) return;
    setState(() => _status = status);
    // First run: as soon as the account is connected, look for its backup.
    if (widget.restoreOnly && status.isConnected && !_cloudChecked) {
      unawaited(_findBackup());
    }
  }

  /// Restore-only: looks for the backup file on Drive.
  Future<void> _findBackup() async {
    setState(() {
      _cloudLooking = true;
      _cloudChecked = false;
      _cloud = null;
      _error = null;
    });
    try {
      final found = await _service.findCloudBackup();
      if (mounted) {
        setState(() {
          _cloud = found;
          _cloudChecked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Could not look for a backup on Google Drive: $e');
      }
    } finally {
      if (mounted) setState(() => _cloudLooking = false);
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
    if (mounted) {
      setState(() {
        _cloud = null;
        _cloudChecked = false;
        _error = null;
      });
    }
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
    // Nothing to ask on a first run: there is no data here to replace.
    if (_hasDataHere(ref)) {
      final sure = await _confirmReplace(
        context,
        title: 'Restore from Google Drive?',
        from: 'the backup on Google Drive',
      );
      if (!sure || !mounted) return;
    }
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
      showAppSnackBar(context, _restoredMessage('Google Drive', restored));
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
    final restoreOnly = widget.restoreOnly;

    final body = <Widget>[
      Text(
        restoreOnly
            ? 'Connect the Google account you backed up with. The backup is '
                  'kept in a hidden folder of your Drive that only this app '
                  'can see; it is found there and restored on this device.'
            : 'Back up your progress, settings, study history and notes to '
                  'your own Google Drive (a hidden app folder only this app '
                  'can see), and restore them on this or another device.',
      ),
      const SizedBox(height: AppSpacing.lg),
    ];

    if (status == null) {
      body.add(const Center(child: CircularProgressIndicator()));
    } else if (!configured) {
      body.add(
        Text(
          restoreOnly
              ? 'Google Drive is not set up in this build. It needs a Google '
                    'OAuth client; docs/DRIVE_SETUP.md says how to make one. '
                    'Until then, restore from a backup file or pasted text '
                    'instead.'
              : 'Google Drive is not set up in this build. It needs a Google '
                    'OAuth client; docs/DRIVE_SETUP.md says how to make one. '
                    'Until then, use Export Backup and Import Backup.',
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
                onPressed: _working == null && !_cloudLooking
                    ? _disconnect
                    : null,
                child: Text(restoreOnly ? 'Use another account' : 'Disconnect'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
      ]);
      if (restoreOnly) {
        body.addAll(_restoreOnlyBody(theme));
      } else {
        body.addAll([
          Text(
            'Last backup from this device: '
            '${last == null ? 'Never' : _formatTime(last)}',
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

    if (!restoreOnly) {
      final frequency = ref.watch(settingsViewModelProvider).backupFrequency;
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
    }

    return PopScope(
      // A restore that is writing must not be cut off by a tap outside.
      canPop: _working == null,
      child: AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.cloud_sync_rounded),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                restoreOnly ? 'Restore from Google Drive' : 'Google Drive Backup',
              ),
            ),
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
            onPressed: _working == null ? () => Navigator.of(context).pop() : null,
            child: Text(restoreOnly ? 'Close' : 'Done'),
          ),
        ],
      ),
    );
  }

  /// First run, connected: the backup found on Drive and the button to restore
  /// it (or why there is nothing to restore).
  List<Widget> _restoreOnlyBody(ThemeData theme) {
    if (_cloudLooking) {
      return [
        const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('Looking for your backup on Google Drive…')),
          ],
        ),
      ];
    }
    final cloud = _cloud;
    if (cloud != null) {
      final modified = cloud.modifiedTime;
      return [
        Row(
          children: [
            const Icon(Icons.cloud_done_outlined),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                modified == null
                    ? 'A backup was found on Google Drive.'
                    : 'A backup was found on Google Drive, saved '
                          '${_formatTime(modified)}.',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          onPressed: _working == null ? _restore : null,
          icon: const Icon(Icons.cloud_download_outlined),
          label: const Text('Restore this backup'),
        ),
      ];
    }
    if (_cloudChecked) {
      return [
        const Text(
          'There is no backup on this Google account yet. If you backed up '
          'with another account, choose "Use another account" and connect '
          'that one.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: _findBackup,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Check again'),
          ),
        ),
      ];
    }
    // The lookup failed (the reason is shown below): let the user try again.
    return [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: _findBackup,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ),
    ];
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
