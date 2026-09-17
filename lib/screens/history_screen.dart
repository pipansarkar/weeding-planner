import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Generic version-history + rollback UI for any change_log-tracked table.
/// Works across every domain table since it only compares two jsonb maps.
class HistoryScreen extends StatefulWidget {
  final String tableName;
  final String rowId;

  const HistoryScreen({super.key, required this.tableName, required this.rowId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _entries = [];
  Map<String, String> _displayNames = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _client
        .from('change_log')
        .select()
        .eq('table_name', widget.tableName)
        .eq('row_id', widget.rowId)
        .order('changed_at', ascending: false);
    final entries = List<Map<String, dynamic>>.from(rows);

    final userIds = entries
        .map((e) => e['changed_by'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (userIds.isNotEmpty) {
      final profiles = await _client.from('profiles').select().inFilter('id', userIds);
      _displayNames = {
        for (final p in List<Map<String, dynamic>>.from(profiles))
          p['id'] as String: p['display_name'] as String? ?? 'Someone',
      };
    }

    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _rollbackTo(Map<String, dynamic> targetState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore this version?'),
        content: const Text(
          'This will update the item to match this earlier version. The current state will be preserved in history too.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
        ],
      ),
    );
    if (confirmed != true) return;

    final cleaned = Map<String, dynamic>.from(targetState)
      ..remove('last_edited_by')
      ..remove('last_edited_at');
    await _client.from(widget.tableName).update(cleaned).eq('id', widget.rowId);
    if (!mounted) return;
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restored to the selected version.')),
      );
    }
  }

  List<String> _changedKeys(Map<String, dynamic>? oldData, Map<String, dynamic>? newData) {
    final keys = <String>{...?oldData?.keys, ...?newData?.keys};
    keys.removeWhere((k) => k == 'last_edited_by' || k == 'last_edited_at');
    return keys.where((k) => oldData?[k] != newData?[k]).toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('No history yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final oldData = entry['old_data'] as Map<String, dynamic>?;
                    final newData = entry['new_data'] as Map<String, dynamic>?;
                    final changedKeys = _changedKeys(oldData, newData);
                    final changedAt = DateTime.parse(entry['changed_at'] as String).toLocal();
                    final who = _displayNames[entry['changed_by']] ?? 'Someone';
                    final op = entry['operation'] as String;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  op == 'insert'
                                      ? Icons.add_circle_outline
                                      : op == 'delete'
                                          ? Icons.delete_outline
                                          : op == 'rollback'
                                              ? Icons.restore
                                              : Icons.edit_outlined,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '$who ${op == 'insert' ? 'created this' : op == 'delete' ? 'deleted this' : op == 'rollback' ? 'restored a version' : 'edited this'}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: Text(
                                DateFormat('MMM d, y • h:mm a').format(changedAt),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            if (changedKeys.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: changedKeys.map((key) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 2),
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '$key: ',
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            TextSpan(text: '${oldData?[key]} → ${newData?[key]}'),
                                          ],
                                        ),
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                            if (newData != null && index != 0) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  icon: const Icon(Icons.restore, size: 16),
                                  label: const Text('Restore this version'),
                                  onPressed: () => _rollbackTo(newData),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
