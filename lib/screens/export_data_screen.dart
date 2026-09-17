import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/guest_provider.dart';
import '../services/backup_service.dart';
import '../utils/file_export.dart';

class ExportDataScreen extends StatelessWidget {
  const ExportDataScreen({super.key});

  Future<void> _exportAllData(BuildContext context) async {
    final json = await BackupService.instance.exportSnapshotJson();
    await shareTextAsFile(
      content: json,
      fileName: 'wedding_planner_export.json',
      subject: 'Wedding Planner Data Export',
    );
  }

  Future<void> _exportGuestsCsv(BuildContext context) async {
    final csv = context.read<GuestProvider>().toCsv();
    await shareTextAsFile(
      content: csv,
      fileName: 'guest_list.csv',
      subject: 'Guest List',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export Data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Export your wedding planning data to share, print, or keep for your records.',
          ),
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.data_object),
              title: const Text('Export All Data (JSON)'),
              subtitle: const Text('Every wedding, guest, budget item, vendor, and more'),
              trailing: const Icon(Icons.ios_share),
              onTap: () => _exportAllData(context),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export Guest List (CSV)'),
              subtitle: const Text('Open in Excel, Sheets, or Numbers'),
              trailing: const Icon(Icons.ios_share),
              onTap: () => _exportGuestsCsv(context),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Planning together with someone else? Export "All Data" and send the '
                    'file to them, then have them open Backup & Restore and restore it on '
                    'their device. This is a one-time copy, not live syncing — the most '
                    'recent import wins, so agree on who has the latest changes before sharing.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
