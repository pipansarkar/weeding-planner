import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/menu_item.dart';
import '../providers/access_provider.dart';
import '../providers/menu_provider.dart';
import '../widgets/request_access_banner.dart';
import 'history_screen.dart';

String _dietaryLabel(DietaryTag tag) {
  switch (tag) {
    case DietaryTag.veg:
      return 'Veg';
    case DietaryTag.nonVeg:
      return 'Non-Veg';
    case DietaryTag.vegan:
      return 'Vegan';
    case DietaryTag.glutenFree:
      return 'Gluten-Free';
    case DietaryTag.jain:
      return 'Jain';
  }
}

Color _dietaryColor(DietaryTag tag) {
  switch (tag) {
    case DietaryTag.veg:
      return Colors.green;
    case DietaryTag.nonVeg:
      return Colors.red;
    case DietaryTag.vegan:
      return Colors.teal;
    case DietaryTag.glutenFree:
      return Colors.orange;
    case DietaryTag.jain:
      return Colors.brown;
  }
}

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  Future<void> _openForm(BuildContext context, {MenuItem? existing}) async {
    final provider = context.read<MenuProvider>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    String course = existing?.course ?? MenuItem.courses.first;
    Set<DietaryTag> tags = {...(existing?.dietaryTags ?? const {})};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              scrollable: true,
              title: Text(existing == null ? 'Add Dish' : 'Edit Dish'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Dish Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: course,
                    decoration: const InputDecoration(labelText: 'Course'),
                    items: MenuItem.courses
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => course = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Dietary Tags', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: DietaryTag.values.map((tag) {
                      final selected = tags.contains(tag);
                      return FilterChip(
                        label: Text(_dietaryLabel(tag)),
                        selected: selected,
                        onSelected: (value) {
                          setDialogState(() {
                            if (value) {
                              tags.add(tag);
                            } else {
                              tags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Notes'),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                if (existing != null)
                  IconButton(
                    tooltip: 'History',
                    icon: const Icon(Icons.history),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => HistoryScreen(tableName: 'menu_items', rowId: existing.id),
                      ),
                    ),
                  ),
                if (existing != null)
                  TextButton(
                    onPressed: () async {
                      await provider.delete(existing.id);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty) return;
                    final itemName = nameCtrl.text.trim();
                    try {
                      if (existing == null) {
                        await provider.add(
                          weddingId: context.read<AccessProvider>().cloudWeddingId!,
                          name: itemName,
                          course: course,
                          dietaryTags: tags,
                          note: noteCtrl.text.trim(),
                        );
                      } else {
                        await provider.update(existing.copyWith(
                          name: itemName,
                          course: course,
                          dietaryTags: tags,
                          note: noteCtrl.text.trim(),
                        ));
                      }
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(existing == null ? 'Added "$itemName"' : 'Saved "$itemName"')),
                        );
                      }
                    } catch (e) {
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not save: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save'),
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
    final provider = context.watch<MenuProvider>();
    final itemsByCourse = provider.itemsByCourse;
    final access = context.watch<AccessProvider>();
    final hasAccess = access.cloudWeddingId == null || access.hasApprovedAccess('menu');

    return Scaffold(
      appBar: AppBar(title: const Text('Wedding Menu')),
      body: !hasAccess
          ? const RequestAccessBanner(section: 'menu')
          : provider.items.isEmpty
          ? const Center(child: Text('No dishes yet. Tap + to add one.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final course in MenuItem.courses)
                  if (itemsByCourse[course]?.isNotEmpty ?? false) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 8),
                      child: Text(
                        course,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    ...itemsByCourse[course]!.map((item) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (item.dietaryTags.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: item.dietaryTags.map((tag) {
                                      return Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          _dietaryLabel(tag),
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                        backgroundColor:
                                            _dietaryColor(tag).withValues(alpha: 0.15),
                                        labelStyle: TextStyle(color: _dietaryColor(tag)),
                                        padding: EdgeInsets.zero,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              if (item.note.isNotEmpty) Text(item.note),
                            ],
                          ),
                          onTap: () => _openForm(context, existing: item),
                        ),
                      );
                    }),
                  ],
              ],
            ),
      floatingActionButton: !hasAccess
          ? null
          : FloatingActionButton(
        heroTag: 'menu_fab',
        onPressed: () => _openForm(context),
        child: const Icon(Icons.restaurant_menu),
      ),
    );
  }
}
