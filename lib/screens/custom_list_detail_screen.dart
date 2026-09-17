import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/custom_list.dart';
import '../models/custom_list_item.dart';
import '../providers/access_provider.dart';
import '../providers/custom_list_provider.dart';
import '../widgets/form_sheet.dart';
import '../widgets/request_access_banner.dart';
import 'create_custom_list_screen.dart';
import 'history_screen.dart';

class CustomListDetailScreen extends StatelessWidget {
  final String listId;

  const CustomListDetailScreen({super.key, required this.listId});

  String _formatValue(CustomFieldDef field, dynamic raw) {
    if (raw == null) return '';
    switch (field.type) {
      case CustomFieldType.checkbox:
        return raw == true ? 'Yes' : 'No';
      case CustomFieldType.date:
        final parsed = DateTime.tryParse(raw as String? ?? '');
        return parsed == null ? '' : DateFormat('MMM d, yyyy').format(parsed);
      case CustomFieldType.number:
      case CustomFieldType.text:
      case CustomFieldType.dropdown:
        return raw.toString();
    }
  }

  Future<void> _openItemForm(
    BuildContext context,
    CustomList list, {
    CustomListItem? existing,
  }) async {
    final provider = context.read<CustomListProvider>();
    await showFormSheet<void>(
      context,
      _CustomListItemForm(provider: provider, list: list, existing: existing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CustomListProvider>();
    final list = provider.lists.where((l) => l.id == listId).firstOrNull;

    if (list == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('List')),
        body: const Center(child: Text('This list no longer exists.')),
      );
    }

    final items = provider.itemsFor(listId);
    final titleField = list.fields.first;
    final subtitleFields = list.fields.skip(1).toList();
    final access = context.watch<AccessProvider>();
    final hasAccess = access.cloudWeddingId == null || access.hasApprovedAccess('custom_lists');

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit fields',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => CreateCustomListScreen(existing: list)),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (action) async {
              if (action == 'delete') {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text('Delete "${list.name}"?'),
                    content: const Text(
                      'This permanently deletes this list and all of its items. This cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await provider.deleteList(listId);
                  if (context.mounted) Navigator.pop(context);
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete List', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ],
      ),
      body: !hasAccess
          ? const RequestAccessBanner(section: 'custom_lists')
          : items.isEmpty
          ? const Center(child: Text('No items yet. Tap + to add one.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final title = _formatValue(titleField, item.values[titleField.id]);
                final subtitleParts = subtitleFields
                    .map((f) {
                      final value = _formatValue(f, item.values[f.id]);
                      return value.isEmpty ? null : '${f.label}: $value';
                    })
                    .whereType<String>()
                    .toList();
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(title.isEmpty ? '(untitled)' : title),
                    subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' • ')),
                    onTap: () => _openItemForm(context, list, existing: item),
                  ),
                );
              },
            ),
      floatingActionButton: !hasAccess
          ? null
          : FloatingActionButton(
              heroTag: 'custom_list_fab_$listId',
              onPressed: () => _openItemForm(context, list),
              child: const Icon(Icons.add),
            ),
    );
  }
}

IconData _fieldInputIcon(CustomFieldType type) {
  switch (type) {
    case CustomFieldType.text:
      return Icons.short_text;
    case CustomFieldType.number:
      return Icons.numbers;
    case CustomFieldType.date:
      return Icons.event;
    case CustomFieldType.checkbox:
      return Icons.check_box_outlined;
    case CustomFieldType.dropdown:
      return Icons.arrow_drop_down_circle_outlined;
  }
}

class _CustomListItemForm extends StatefulWidget {
  final CustomListProvider provider;
  final CustomList list;
  final CustomListItem? existing;

  const _CustomListItemForm({
    required this.provider,
    required this.list,
    required this.existing,
  });

  @override
  State<_CustomListItemForm> createState() => _CustomListItemFormState();
}

class _CustomListItemFormState extends State<_CustomListItemForm> {
  late final Map<String, dynamic> values;
  late final Map<String, TextEditingController> controllers;
  bool saving = false;

  CustomListItem? get existing => widget.existing;

  @override
  void initState() {
    super.initState();
    values = Map<String, dynamic>.from(existing?.values ?? {});
    controllers = {
      for (final field in widget.list.fields)
        if (field.type == CustomFieldType.text || field.type == CustomFieldType.number)
          field.id: TextEditingController(text: values[field.id]?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _delete() async {
    await widget.provider.deleteItem(widget.list.id, existing!.id);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    final titleField = widget.list.fields.first;
    final itemName =
        controllers[titleField.id]?.text.trim() ?? values[titleField.id]?.toString() ?? '';
    setState(() => saving = true);
    try {
      for (final entry in controllers.entries) {
        final field = widget.list.fields.firstWhere((f) => f.id == entry.key);
        final text = entry.value.text.trim();
        if (field.type == CustomFieldType.number) {
          values[entry.key] = double.tryParse(text);
        } else {
          values[entry.key] = text.isEmpty ? null : text;
        }
      }
      if (existing == null) {
        await widget.provider.addItem(listId: widget.list.id, values: values);
      } else {
        await widget.provider.updateItem(existing!.copyWith(values: values));
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

  Widget _buildFieldInput(CustomFieldDef field) {
    switch (field.type) {
      case CustomFieldType.text:
        return TextField(
          controller: controllers[field.id],
          decoration: InputDecoration(
            labelText: field.label,
            prefixIcon: Icon(_fieldInputIcon(field.type)),
          ),
        );
      case CustomFieldType.number:
        return TextField(
          controller: controllers[field.id],
          decoration: InputDecoration(
            labelText: field.label,
            prefixIcon: Icon(_fieldInputIcon(field.type)),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        );
      case CustomFieldType.checkbox:
        final checked = values[field.id] == true;
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          secondary: Icon(_fieldInputIcon(field.type)),
          value: checked,
          onChanged: (value) => setState(() => values[field.id] = value),
        );
      case CustomFieldType.date:
        final raw = values[field.id] as String?;
        final date = raw == null ? null : DateTime.tryParse(raw);
        return FormPickerField(
          label: field.label,
          value: date == null ? 'Not set' : DateFormat('MMM d, yyyy').format(date),
          icon: _fieldInputIcon(field.type),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked != null) {
              setState(() => values[field.id] = picked.toIso8601String());
            }
          },
        );
      case CustomFieldType.dropdown:
        final current = values[field.id] as String?;
        return DropdownButtonFormField<String>(
          initialValue: field.options.contains(current) ? current : null,
          decoration: InputDecoration(
            labelText: field.label,
            prefixIcon: Icon(_fieldInputIcon(field.type)),
          ),
          items: field.options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: (value) => setState(() => values[field.id] = value),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: existing == null ? 'Add Item' : 'Edit Item',
      saving: saving,
      onSave: _save,
      onDelete: existing == null ? null : _delete,
      onHistory: existing == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      HistoryScreen(tableName: 'custom_list_items', rowId: existing!.id),
                ),
              ),
      children: [
        FormSection(
          title: 'Details',
          icon: Icons.list_alt_outlined,
          margin: EdgeInsets.zero,
          children: widget.list.fields.map(_buildFieldInput).toList(),
        ),
      ],
    );
  }
}
