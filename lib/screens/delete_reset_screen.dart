import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/access_provider.dart';
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

class DeleteResetScreen extends StatefulWidget {
  const DeleteResetScreen({super.key});

  @override
  State<DeleteResetScreen> createState() => _DeleteResetScreenState();
}

class _DeleteResetScreenState extends State<DeleteResetScreen> {
  bool _busy = false;

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteCurrentWedding() async {
    final weddingProvider = context.read<WeddingProvider>();
    final wedding = weddingProvider.activeWedding;
    final access = context.read<AccessProvider>();
    final cloudWeddingId = access.cloudWeddingId;

    if (cloudWeddingId != null) {
      if (!access.isOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only the wedding owner can delete this wedding.')),
        );
        return;
      }

      final confirmed = await _confirm(
        title: 'Delete this wedding?',
        message:
            'This permanently deletes this wedding and all of its checklist, budget, guest, vendor, '
            'timeline, seating, menu, and other collaborative data for everyone. This cannot be undone.',
        confirmLabel: 'Delete Wedding',
      );
      if (!confirmed) return;

      setState(() => _busy = true);
      try {
        await access.deleteWedding(cloudWeddingId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wedding deleted')),
          );
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    if (wedding == null) return;
    if (weddingProvider.weddings.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Can't delete the only wedding. Add another one first.")),
      );
      return;
    }

    final confirmed = await _confirm(
      title: 'Delete "${wedding.displayName}"?',
      message:
          'This permanently deletes this wedding and all of its locally stored mood board data. This cannot be undone.',
      confirmLabel: 'Delete Wedding',
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      await weddingProvider.deleteWedding(wedding.id);
      if (!mounted) return;
      await _reloadAllProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wedding deleted')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetAllData() async {
    final access = context.read<AccessProvider>();
    final cloudWeddingId = access.cloudWeddingId;
    final canDeleteCloudWedding = cloudWeddingId != null && access.isOwner;

    final message = cloudWeddingId == null
        ? 'This permanently deletes every wedding and all associated data on this device. '
            'Consider creating a backup first. This cannot be undone.'
        : canDeleteCloudWedding
            ? 'This permanently deletes your wedding and all of its checklist, budget, guest, vendor, '
                'timeline, seating, menu, and other collaborative data for everyone, plus everything stored '
                'on this device. Consider creating a backup first. This cannot be undone.'
            : "You're a collaborator, not the owner, so the shared wedding data can't be deleted from here. "
                'This will remove it from this device and reset everything stored locally. This cannot be undone.';

    final confirmed = await _confirm(
      title: 'Reset All Data?',
      message: message,
      confirmLabel: 'Reset Everything',
    );
    if (!confirmed) return;

    setState(() => _busy = true);
    try {
      if (canDeleteCloudWedding) {
        await access.deleteWedding(cloudWeddingId);
      }
      await BackupService.instance.resetAllData();
      if (!mounted) return;
      await context.read<WeddingProvider>().load();
      if (!mounted) return;
      await _reloadAllProviders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data reset')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadAllProviders() async {
    if (!mounted) return;
    final weddingId = context.read<WeddingProvider>().activeWeddingId;
    if (weddingId != null) {
      await context.read<MoodBoardProvider>().load(weddingId: weddingId);
    }

    if (!mounted) return;
    final cloudWeddingId = context.read<AccessProvider>().cloudWeddingId;
    if (cloudWeddingId == null) return;
    await Future.wait([
      context.read<ChecklistProvider>().load(weddingId: cloudWeddingId),
      context.read<BudgetProvider>().load(weddingId: cloudWeddingId),
      context.read<GuestProvider>().load(weddingId: cloudWeddingId),
      context.read<VendorProvider>().load(weddingId: cloudWeddingId),
      context.read<TimelineProvider>().load(weddingId: cloudWeddingId),
      context.read<EmergencyContactProvider>().load(weddingId: cloudWeddingId),
      context.read<SeatingProvider>().load(weddingId: cloudWeddingId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final wedding = context.watch<WeddingProvider>().activeWedding;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete & Reset')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'These actions permanently delete data and cannot be undone. Consider backing up first.',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text('Delete "${wedding?.displayName ?? 'Current Wedding'}"'),
                  subtitle: const Text('Removes this wedding and all of its data'),
                  onTap: _busy ? null : _deleteCurrentWedding,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Reset All Data'),
                  subtitle: const Text('Deletes every wedding and all data on this device'),
                  onTap: _busy ? null : _resetAllData,
                ),
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
