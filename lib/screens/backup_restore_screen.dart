import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/budget_provider.dart';
import '../providers/checklist_provider.dart';
import '../providers/emergency_contact_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/mood_board_provider.dart';
import '../providers/seating_provider.dart';
import '../providers/timeline_provider.dart';
import '../providers/vendor_provider.dart';
import '../providers/wedding_provider.dart';
import '../services/backup_service.dart';
import '../utils/file_export.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  late Future<List<BackupFile>> _backupsFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _backupsFuture = BackupService.instance.listBackups();
  }

  void _refresh() {
    setState(() => _backupsFuture = BackupService.instance.listBackups());
  }

  Future<void> _createBackup() async {
    setState(() => _busy = true);
    try {
      await BackupService.instance.createBackup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
      _refresh();
    }
  }

  Future<void> _reloadAllProviders() async {
    final weddingProvider = context.read<WeddingProvider>();
    await weddingProvider.load();
    if (!mounted) return;
    final weddingId = weddingProvider.activeWeddingId;
    if (weddingId == null) return;
    await Future.wait([
      context.read<ChecklistProvider>().load(weddingId: weddingId),
      context.read<BudgetProvider>().load(weddingId: weddingId),
      context.read<GuestProvider>().load(weddingId: weddingId),
      context.read<VendorProvider>().load(weddingId: weddingId),
      context.read<TimelineProvider>().load(weddingId: weddingId),
      context.read<EmergencyContactProvider>().load(weddingId: weddingId),
      context.read<SeatingProvider>().load(weddingId: weddingId),
      context.read<MoodBoardProvider>().load(weddingId: weddingId),
    ]);
  }

  Future<void> _restore(BackupFile backup) async {
    final confirmed = await _confirmRestore(backup.fileName);
    if (!confirmed) return;
    final content = await BackupService.instance.readBackupContent(backup.fileName);
    await _applyRestore(content);
  }

  Future<void> _restoreFromFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;

    final confirmed = await _confirmRestore(path.split('/').last);
    if (!confirmed) return;
    final content = await File(path).readAsString();
    await _applyRestore(content);
  }

  Future<bool> _confirmRestore(String sourceLabel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Backup?'),
        content: Text(
          'This replaces all current data with the contents of "$sourceLabel". '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _applyRestore(String content) async {
    setState(() => _busy = true);
    try {
      await BackupService.instance.restoreFromJson(content);
      if (!mounted) return;
      await _reloadAllProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data restored')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Restore failed: invalid backup file')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(BackupFile backup) async {
    final content = await BackupService.instance.readBackupContent(backup.fileName);
    await shareTextAsFile(content: content, fileName: backup.fileName, subject: 'Wedding Planner Backup');
  }

  Future<void> _delete(BackupFile backup) async {
    await BackupService.instance.deleteBackup(backup.fileName);
    _refresh();
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Backups are saved on this device and include all weddings and their data.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _createBackup,
                icon: const Icon(Icons.add),
                label: const Text('Create Backup Now'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _restoreFromFile,
                icon: const Icon(Icons.file_open),
                label: const Text('Restore from File…'),
              ),
              const SizedBox(height: 20),
              Text('Saved Backups', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              FutureBuilder<List<BackupFile>>(
                future: _backupsFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final backups = snapshot.data!;
                  if (backups.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('No backups yet.'),
                    );
                  }
                  return Column(
                    children: backups.map((backup) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text(
                            DateFormat('MMM d, yyyy – h:mm a').format(backup.createdAt),
                          ),
                          subtitle: Text(_formatSize(backup.sizeBytes)),
                          trailing: PopupMenuButton<String>(
                            onSelected: (action) {
                              switch (action) {
                                case 'restore':
                                  _restore(backup);
                                  break;
                                case 'share':
                                  _share(backup);
                                  break;
                                case 'delete':
                                  _delete(backup);
                                  break;
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'restore', child: Text('Restore')),
                              PopupMenuItem(value: 'share', child: Text('Share')),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black.withValues(alpha: 0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
