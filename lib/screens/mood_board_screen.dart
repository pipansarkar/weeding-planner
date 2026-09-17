import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/mood_board_item.dart';
import '../providers/mood_board_provider.dart';
import '../providers/wedding_provider.dart';
import '../widgets/form_sheet.dart';

class MoodBoardScreen extends StatelessWidget {
  const MoodBoardScreen({super.key});

  Future<void> _addImage(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    if (!context.mounted) return;

    final provider = context.read<MoodBoardProvider>();
    await showFormSheet<void>(context, _MoodBoardForm(provider: provider, imagePath: picked.path));
  }

  Future<void> _viewImage(BuildContext context, MoodBoardItem item) async {
    final provider = context.read<MoodBoardProvider>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(item.imagePath), fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              Text(item.category, style: Theme.of(context).textTheme.labelMedium),
              if (item.caption.isNotEmpty) Text(item.caption),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await provider.delete(item.id);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MoodBoardProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Mood Board')),
      body: items.isEmpty
          ? const Center(child: Text('No inspiration images yet. Tap + to add one.'))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return GestureDetector(
                  onTap: () => _viewImage(context, item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(File(item.imagePath), fit: BoxFit.cover),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            color: Colors.black.withValues(alpha: 0.5),
                            child: Text(
                              item.category,
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'mood_board_fab',
        onPressed: () => _addImage(context),
        child: const Icon(Icons.add_photo_alternate),
      ),
    );
  }
}

class _MoodBoardForm extends StatefulWidget {
  final MoodBoardProvider provider;
  final String imagePath;

  const _MoodBoardForm({required this.provider, required this.imagePath});

  @override
  State<_MoodBoardForm> createState() => _MoodBoardFormState();
}

class _MoodBoardFormState extends State<_MoodBoardForm> {
  final captionCtrl = TextEditingController();
  String category = MoodBoardItem.categories.first;
  bool saving = false;

  @override
  void dispose() {
    captionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final caption = captionCtrl.text.trim();
    final displayName = caption.isEmpty ? 'Photo' : caption;
    setState(() => saving = true);
    try {
      await widget.provider.add(
        weddingId: context.read<WeddingProvider>().activeWeddingId!,
        imagePath: widget.imagePath,
        category: category,
        caption: caption,
      );
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Added "$displayName"')),
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
      title: 'Add to Mood Board',
      saving: saving,
      onSave: _save,
      saveLabel: 'Add',
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(File(widget.imagePath), height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 16),
        FormSection(
          title: 'Details',
          icon: Icons.image_outlined,
          margin: EdgeInsets.zero,
          children: [
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Category',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: MoodBoardItem.categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => category = v!),
            ),
            TextField(
              controller: captionCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Caption (optional)',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
