import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/custom_list.dart';
import '../providers/access_provider.dart';
import '../providers/custom_list_provider.dart';

String fieldTypeLabel(CustomFieldType type) {
  switch (type) {
    case CustomFieldType.text:
      return 'Text';
    case CustomFieldType.number:
      return 'Number';
    case CustomFieldType.date:
      return 'Date';
    case CustomFieldType.checkbox:
      return 'Checkbox';
    case CustomFieldType.dropdown:
      return 'Dropdown';
  }
}

IconData fieldTypeIcon(CustomFieldType type) {
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

class CreateCustomListScreen extends StatefulWidget {
  final CustomList? existing;

  const CreateCustomListScreen({super.key, this.existing});

  @override
  State<CreateCustomListScreen> createState() => _CreateCustomListScreenState();
}

class _CreateCustomListScreenState extends State<CreateCustomListScreen> {
  late final TextEditingController _nameCtrl;
  late List<CustomFieldDef> _fields;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _fields = List.of(widget.existing?.fields ?? const []);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addOrEditField({CustomFieldDef? existing, int? index}) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final optionsCtrl = TextEditingController(text: existing?.options.join(', ') ?? '');
    CustomFieldType type = existing?.type ?? CustomFieldType.text;

    final result = await showDialog<CustomFieldDef>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(existing == null ? 'Add Field' : 'Edit Field'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(labelText: 'Field Name'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CustomFieldType>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Field Type'),
                      items: CustomFieldType.values
                          .map((t) => DropdownMenuItem(
                                value: t,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(fieldTypeIcon(t), size: 18),
                                    const SizedBox(width: 8),
                                    Text(fieldTypeLabel(t)),
                                  ],
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => type = value);
                      },
                    ),
                    if (type == CustomFieldType.dropdown) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: optionsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Options (comma separated)',
                          hintText: 'Low, Medium, High',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final label = labelCtrl.text.trim();
                    if (label.isEmpty) return;
                    final options = optionsCtrl.text
                        .split(',')
                        .map((o) => o.trim())
                        .where((o) => o.isNotEmpty)
                        .toList();
                    Navigator.pop(
                      dialogContext,
                      CustomFieldDef(
                        id: existing?.id ?? const Uuid().v4(),
                        label: label,
                        type: type,
                        options: type == CustomFieldType.dropdown ? options : const [],
                      ),
                    );
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() {
      if (index != null) {
        _fields[index] = result;
      } else {
        _fields.add(result);
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _fields.isEmpty) return;
    final provider = context.read<CustomListProvider>();
    final weddingId = context.read<AccessProvider>().cloudWeddingId!;

    if (widget.existing == null) {
      await provider.addList(weddingId: weddingId, name: name, fields: _fields);
    } else {
      await provider.updateList(widget.existing!.copyWith(name: name, fields: _fields));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New Custom List' : 'Edit List'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'List Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fields', style: Theme.of(context).textTheme.titleMedium),
              TextButton.icon(
                onPressed: () => _addOrEditField(),
                icon: const Icon(Icons.add),
                label: const Text('Add Field'),
              ),
            ],
          ),
          if (_fields.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Add at least one field, e.g. "Item Name".'),
            )
          else
            ..._fields.asMap().entries.map((entry) {
              final index = entry.key;
              final field = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Icon(fieldTypeIcon(field.type)),
                  title: Text(field.label),
                  subtitle: Text(
                    field.type == CustomFieldType.dropdown
                        ? '${fieldTypeLabel(field.type)} • ${field.options.join(', ')}'
                        : fieldTypeLabel(field.type),
                  ),
                  onTap: () => _addOrEditField(existing: field, index: index),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => setState(() => _fields.removeAt(index)),
                  ),
                ),
              );
            }),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('Save List'),
          ),
        ],
      ),
    );
  }
}
