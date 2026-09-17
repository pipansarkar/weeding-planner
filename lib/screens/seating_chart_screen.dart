import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/guest.dart';
import '../models/seating_table.dart';
import '../providers/access_provider.dart';
import '../providers/guest_provider.dart';
import '../providers/seating_provider.dart';
import '../widgets/form_sheet.dart';
import '../widgets/request_access_banner.dart';
import 'history_screen.dart';

class SeatingChartScreen extends StatelessWidget {
  const SeatingChartScreen({super.key});

  Future<void> _addTable(BuildContext context) async {
    final provider = context.read<SeatingProvider>();
    await showFormSheet<void>(context, _AddTableForm(provider: provider));
  }

  Future<void> _assignGuests(BuildContext context, SeatingTable table) async {
    final seatingProvider = context.read<SeatingProvider>();
    final guestProvider = context.read<GuestProvider>();
    final unseated = guestProvider.guests
        .where((g) => !seatingProvider.seatedGuestIds.contains(g.id) ||
            table.guestIds.contains(g.id))
        .toList();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text('Assign Guests — ${table.name}'),
              content: SizedBox(
                width: 400,
                height: 400,
                child: unseated.isEmpty
                    ? const Center(child: Text('No unseated guests available.'))
                    : ListView.builder(
                        itemCount: unseated.length,
                        itemBuilder: (context, index) {
                          final guest = unseated[index];
                          final assigned = table.guestIds.contains(guest.id);
                          return CheckboxListTile(
                            title: Text(guest.name),
                            subtitle: Text(guest.category),
                            value: assigned,
                            onChanged: (v) async {
                              if (v == true) {
                                await seatingProvider.assignGuest(table.id, guest.id);
                              } else {
                                await seatingProvider.unassignGuest(table.id, guest.id);
                              }
                              setDialogState(() {});
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final seatingProvider = context.watch<SeatingProvider>();
    final guestProvider = context.watch<GuestProvider>();
    final tables = seatingProvider.tables;
    final access = context.watch<AccessProvider>();
    final hasAccess = access.cloudWeddingId == null || access.hasApprovedAccess('seating');

    return Scaffold(
      appBar: AppBar(title: const Text('Seating Chart')),
      body: !hasAccess
          ? const RequestAccessBanner(section: 'seating')
          : tables.isEmpty
          ? const Center(child: Text('No tables yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tables.length,
              itemBuilder: (context, index) {
                final table = tables[index];
                final seated = table.guestIds
                    .map<Guest?>((id) => guestProvider.guests
                        .cast<Guest?>()
                        .firstWhere((g) => g!.id == id, orElse: () => null))
                    .whereType<Guest>()
                    .toList();
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                table.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text('${seated.length}/${table.capacity}',
                                style: Theme.of(context).textTheme.labelMedium),
                            IconButton(
                              icon: const Icon(Icons.person_add_alt, size: 20),
                              onPressed: () => _assignGuests(context, table),
                            ),
                            IconButton(
                              icon: const Icon(Icons.history, size: 20),
                              tooltip: 'History',
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      HistoryScreen(tableName: 'seating_tables', rowId: table.id),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => seatingProvider.delete(table.id),
                            ),
                          ],
                        ),
                        if (seated.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: seated
                                .map<Widget>((g) => Chip(
                                      visualDensity: VisualDensity.compact,
                                      label: Text(g.name, style: const TextStyle(fontSize: 12)),
                                    ))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: !hasAccess
          ? null
          : FloatingActionButton(
        heroTag: 'seating_chart_fab',
        onPressed: () => _addTable(context),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddTableForm extends StatefulWidget {
  final SeatingProvider provider;

  const _AddTableForm({required this.provider});

  @override
  State<_AddTableForm> createState() => _AddTableFormState();
}

class _AddTableFormState extends State<_AddTableForm> {
  final nameCtrl = TextEditingController();
  final capacityCtrl = TextEditingController(text: '8');
  bool saving = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a table name')),
      );
      return;
    }
    final itemName = nameCtrl.text.trim();
    final capacity = int.tryParse(capacityCtrl.text.trim()) ?? 8;
    setState(() => saving = true);
    try {
      await widget.provider.add(
        weddingId: context.read<AccessProvider>().cloudWeddingId!,
        name: itemName,
        capacity: capacity,
      );
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "$itemName"')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: 'Add Table',
      saving: saving,
      onSave: _save,
      children: [
        FormSection(
          title: 'Details',
          icon: Icons.table_restaurant_outlined,
          margin: EdgeInsets.zero,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Table name',
                prefixIcon: Icon(Icons.drive_file_rename_outline),
              ),
            ),
            TextField(
              controller: capacityCtrl,
              decoration: const InputDecoration(
                labelText: 'Capacity',
                prefixIcon: Icon(Icons.people_outline),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ],
    );
  }
}
