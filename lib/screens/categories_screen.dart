import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/category_provider.dart';

/// Lets any collaborator with write access add or remove custom categories,
/// and hide/restore built-in ones, for Budget, Vendors, Checklist, and
/// Schedule -- shared live with everyone on the wedding.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _sections = ['budget', 'vendors', 'checklist', 'timeline', 'guests'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _sections.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addCategory(BuildContext context, String section) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add ${categorySectionLabels[section]} Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Category name'),
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ctrl.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    if (context.mounted) {
      try {
        await context.read<CategoryProvider>().addCategory(section, name);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add "$name": $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmRemove(
      BuildContext context, String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove "$name"?'),
        content: const Text(
          'Existing items already using this category keep it -- '
          "it just won't be offered for new items anymore.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<CategoryProvider>().removeCategory(id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not remove "$name": $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmHideBuiltIn(
      BuildContext context, String section, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove "$name"?'),
        content: const Text(
          'This is one of the app\'s built-in categories. Existing items '
          "already using it keep it -- it just won't be offered for new "
          'items anymore. You can bring it back later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        await context.read<CategoryProvider>().hideBuiltIn(section, name);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not remove "$name": $e')),
          );
        }
      }
    }
  }

  Future<void> _unhideBuiltIn(BuildContext context, String section, String name) async {
    try {
      await context.read<CategoryProvider>().unhideBuiltIn(section, name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not restore "$name": $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _sections
              .map((s) => Tab(text: categorySectionLabels[s]))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _sections.map((section) {
          final visibleBuiltIn = categories.visibleBuiltInsFor(section);
          final hiddenBuiltIn = categories.hiddenBuiltInsFor(section);
          final custom = categories.customFor(section);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                onPressed: () => _addCategory(context, section),
                icon: const Icon(Icons.add),
                label: Text('Add ${categorySectionLabels[section]} Category'),
              ),
              const SizedBox(height: 20),
              if (custom.isNotEmpty) ...[
                Text('Your categories', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ...custom.map((row) => Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: ListTile(
                        title: Text(row['name'] as String),
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          tooltip: 'Remove',
                          onPressed: () => _confirmRemove(
                            context,
                            row['id'] as String,
                            row['name'] as String,
                          ),
                        ),
                      ),
                    )),
                const SizedBox(height: 20),
              ],
              Text('Built-in categories', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Tap delete to stop offering one for new items.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: visibleBuiltIn
                    .map((c) => Chip(
                          label: Text(c),
                          deleteIcon: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onDeleted: () => _confirmHideBuiltIn(context, section, c),
                        ))
                    .toList(),
              ),
              if (hiddenBuiltIn.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Hidden built-ins', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: hiddenBuiltIn
                      .map((c) => ActionChip(
                            label: Text(c),
                            avatar: const Icon(Icons.add, size: 16),
                            onPressed: () => _unhideBuiltIn(context, section, c),
                          ))
                      .toList(),
                ),
              ],
            ],
          );
        }).toList(),
      ),
    );
  }
}
