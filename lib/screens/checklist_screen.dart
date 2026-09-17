import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/checklist_item.dart';
import '../providers/access_provider.dart';
import '../providers/category_provider.dart';
import '../providers/checklist_provider.dart';
import '../services/notification_service.dart';
import '../widgets/form_sheet.dart';
import '../widgets/request_access_banner.dart';
import '../widgets/root_scaffold_key.dart';
import 'history_screen.dart';

class ChecklistScreen extends StatelessWidget {
  const ChecklistScreen({super.key});

  Future<void> _openForm(BuildContext context, {ChecklistItem? existing}) async {
    final provider = context.read<ChecklistProvider>();
    final categories = context.read<CategoryProvider>().categoriesFor('checklist');
    if (existing != null && !categories.contains(existing.category)) {
      categories.add(existing.category);
    }
    await showFormSheet<void>(
      context,
      _ChecklistForm(provider: provider, categories: categories, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChecklistProvider>();
    final items = provider.items;
    final access = context.watch<AccessProvider>();
    final hasAccess = access.cloudWeddingId == null || access.hasApprovedAccess('checklist');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => rootScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Checklist'),
      ),
      body: !hasAccess
          ? const RequestAccessBanner(section: 'checklist')
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryChip(
                    label: 'Completed',
                    count: provider.completedCount,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryChip(
                    label: 'Pending',
                    count: provider.pendingCount,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No checklist items yet. Tap + to add one.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final done = item.status == ChecklistStatus.completed;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: Checkbox(
                            value: done,
                            onChanged: (_) => provider.toggleStatus(item),
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              color: done
                                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                                  : null,
                            ),
                          ),
                          subtitle: Text(
                            [
                              item.category,
                              if (item.date != null)
                                DateFormat('MMM d, yyyy').format(item.date!),
                              if (item.note.isNotEmpty) item.note,
                            ].join(' • '),
                          ),
                          trailing: Chip(
                            label: Text(done ? 'Completed' : 'Pending'),
                            backgroundColor:
                                (done ? Colors.green : Colors.orange).withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                              color: done ? Colors.green[800] : Colors.orange[800],
                              fontSize: 12,
                            ),
                          ),
                          onTap: () => _openForm(context, existing: item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: !hasAccess
          ? null
          : FloatingActionButton(
              heroTag: 'checklist_fab',
              onPressed: () => _openForm(context),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _ChecklistForm extends StatefulWidget {
  final ChecklistProvider provider;
  final List<String> categories;
  final ChecklistItem? existing;

  const _ChecklistForm({
    required this.provider,
    required this.categories,
    required this.existing,
  });

  @override
  State<_ChecklistForm> createState() => _ChecklistFormState();
}

class _ChecklistFormState extends State<_ChecklistForm> {
  late final TextEditingController nameCtrl;
  late final TextEditingController noteCtrl;
  late String category;
  DateTime? date;
  late ChecklistStatus status;
  bool saving = false;

  ChecklistItem? get existing => widget.existing;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: existing?.name ?? '');
    noteCtrl = TextEditingController(text: existing?.note ?? '');
    category = existing?.category ?? widget.categories.first;
    date = existing?.date;
    status = existing?.status ?? ChecklistStatus.pending;
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => date = picked);
  }

  Future<void> _delete() async {
    await widget.provider.delete(existing!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }
    final itemName = nameCtrl.text.trim();
    setState(() => saving = true);
    try {
      String itemId;
      if (existing == null) {
        itemId = await widget.provider.add(
          weddingId: context.read<AccessProvider>().cloudWeddingId!,
          name: itemName,
          category: category,
          date: date,
          note: noteCtrl.text.trim(),
          status: status,
        );
      } else {
        itemId = existing!.id;
        await widget.provider.update(existing!.copyWith(
          name: itemName,
          category: category,
          date: date,
          note: noteCtrl.text.trim(),
          status: status,
        ));
      }
      await NotificationService.instance.cancelReminder(itemId);
      if (date != null && status == ChecklistStatus.pending) {
        await NotificationService.instance.scheduleReminder(
          sourceId: itemId,
          title: 'Checklist reminder: $itemName',
          body: 'Due today — $category',
          dateTime: DateTime(date!.year, date!.month, date!.day, 9),
        );
      }
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Added "$itemName"' : 'Saved "$itemName"')),
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
      title: existing == null ? 'Add Checklist Item' : 'Edit Item',
      saving: saving,
      onSave: _save,
      onDelete: existing == null ? null : _delete,
      onHistory: existing == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HistoryScreen(tableName: 'checklist_items', rowId: existing!.id),
                ),
              ),
      children: [
        FormSection(
          title: 'Details',
          icon: Icons.checklist_outlined,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.drive_file_rename_outline),
              ),
            ),
            DropdownButtonFormField<String>(
              initialValue: category,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: widget.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
          ],
        ),
        FormSection(
          title: 'Schedule',
          icon: Icons.event_outlined,
          children: [
            FormPickerField(
              label: 'Due date',
              value: date == null ? 'Pick a date' : DateFormat('MMM d, yyyy').format(date!),
              icon: Icons.calendar_month,
              onTap: _pickDate,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Completed'),
              secondary: const Icon(Icons.task_alt),
              value: status == ChecklistStatus.completed,
              onChanged: (v) => setState(
                  () => status = v ? ChecklistStatus.completed : ChecklistStatus.pending),
            ),
          ],
        ),
        FormSection(
          title: 'Notes',
          icon: Icons.notes_outlined,
          margin: EdgeInsets.zero,
          children: [
            TextField(
              controller: noteCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 3,
              minLines: 2,
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SummaryChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('$count',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
